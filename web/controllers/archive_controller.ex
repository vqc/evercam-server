defmodule EvercamMedia.ArchiveController do
  use EvercamMedia.Web, :controller
  alias EvercamMedia.ArchiveView
  alias EvercamMedia.Util

  @status %{pending: 0, processing: 1, completed: 2, failed: 3}

  def index(conn, %{"id" => exid} = params) do
    current_user = conn.assigns[:current_user]
    camera = Camera.get_full(exid)
    status = params["status"]

    with :ok <- ensure_camera_exists(camera, exid, conn),
         :ok <- ensure_can_list(current_user, camera, conn)
    do
      archives =
        Archive
        |> Archive.by_camera_id(camera.id)
        |> Archive.with_status_if_given(status)
        |> Archive.get_all_with_associations

      conn
      |> render(ArchiveView, "index.json", %{archives: archives})
    end
  end

  def show(conn, %{"id" => exid, "archive_id" => archive_id} = params) do
    current_user = conn.assigns[:current_user]
    camera = Camera.by_exid_with_associations(exid)

    with :ok <- valid_params(conn, params),
         :ok <- ensure_camera_exists(camera, exid, conn),
         :ok <- ensure_can_list(current_user, camera, conn)
    do
      archive = Archive.by_exid(archive_id)

      case archive do
        nil ->
          conn
          |> render_error(404, "Archive '#{archive_id}' not found!")
        _ ->
          conn
          |> render(ArchiveView, "show.json", %{archive: archive})
      end
    end
  end

  def create(conn, %{"id" => exid} = params) do
    current_user = conn.assigns[:current_user]
    camera = Camera.get_full(exid)

    with :ok <- ensure_camera_exists(camera, exid, conn),
         :ok <- ensure_can_list(current_user, camera, conn)
    do
      create_clip(params, camera, conn)
    end
  end

  def delete(conn, %{"id" => exid, "archive_id" => archive_id} = params) do
    current_user = conn.assigns[:current_user]
    camera = Camera.get_full(exid)

    with :ok <- valid_params(conn, params),
         :ok <- ensure_camera_exists(camera, exid, conn),
         :ok <- ensure_can_delete(current_user, camera, conn),
         :ok <- ensure_archive(conn, archive_id)
    do
      Archive.delete_by_exid(archive_id)

      conn
      |> json(%{message: "Archive has been deleted!"})
    end
  end

  defp create_clip(params, camera, conn) do
    offset = offset(camera.timezone)
    from_date = clip_date(params["from_date"], offset)
    to_date = clip_date(params["to_date"], offset)
    clip_exid = generate_exid(params["title"])
    current_date_time =
      camera
      |> Camera.get_timezone
      |> Calendar.DateTime.now!
      |> Calendar.DateTime.to_erl
    user_id =
      params["requested_by"]
      |> User.by_username
      |> Util.deep_get([:id], "")

    params =
      params
      |> Map.delete("id")
      |> Map.delete("api_id")
      |> Map.delete("api_key")
      |> Map.merge(%{
        "requested_by" => user_id,
        "camera_id" => camera.id,
        "title" => params["title"],
        "from_date" => from_date,
        "to_date" => to_date,
        "status" => @status.pending,
        "exid" => clip_exid
      })

    changeset = Archive.changeset(%Archive{}, params)

    cond do
      !changeset.valid? ->
        render_error(conn, 400, Util.parse_changeset(changeset))
      to_date < from_date ->
        render_error(conn, 400, "To date cannot be less than from date.")
      current_date_time <= from_date ->
        render_error(conn, 400, "From date cannot be greater than current time.")
      current_date_time <= to_date ->
        render_error(conn, 400, "To date cannot be greater than current time.")
      to_date == from_date ->
        render_error(conn, 400, "To date and from date cannot be same.")
      date_difference(from_date, to_date) > 7200 ->
        render_error(conn, 400, "Clip duration cannot be greater than 2 hours.")
      true ->
        case Repo.insert(changeset) do
          {:ok, archive} ->
            conn
            |> render(ArchiveView, "show.json", %{archive: archive |> Repo.preload(:camera) |> Repo.preload(:user)})
          {:error, changeset} ->
            render_error(conn, 400, Util.parse_changeset(changeset))
        end
    end
  end

  defp ensure_camera_exists(nil, exid, conn) do
    render_error(conn, 404, "Camera '#{exid}' not found!")
  end
  defp ensure_camera_exists(_camera, _exid, _conn), do: :ok

  defp ensure_can_list(current_user, camera, conn) do
    if current_user && Permission.Camera.can_list?(current_user, camera) do
      :ok
    else
      render_error(conn, 401, "Unauthorized.")
    end
  end

  defp ensure_can_delete(current_user, camera, conn) do
    if current_user && Permission.Camera.can_delete?(current_user, camera) do
      :ok
    else
      render_error(conn, 401, "Unauthorized.")
    end
  end

  defp valid_params(conn, params) do
    if present?(params["id"]) && present?(params["archive_id"]) do
      :ok
    else
      render_error(conn, 400, "Parameters are invalid!")
    end
  end

  defp present?(param) when param in [nil, ""], do: false
  defp present?(_param), do: true

  defp ensure_archive(conn, archive_id) do
    case Archive.by_exid(archive_id) do
      nil -> render_error(conn, 404, "Archive '#{archive_id}' not found!")
      _ -> :ok
    end
  end

  defp offset(nil), do: offset("Etc/UTC")
  defp offset(timezone) do
    timezone
    |> Calendar.DateTime.now!
    |> Map.get(:utc_offset)
  end

  defp clip_date(unix_timestamp, _offset) when unix_timestamp in ["", nil], do: nil
  defp clip_date(unix_timestamp, offset) do
    unix_timestamp
    |> Calendar.DateTime.Parse.unix!
    |> Calendar.DateTime.advance(offset)
    |> elem(1)
    |> Calendar.DateTime.to_erl
  end

  defp date_difference(from_date, to_date) do
    from = Calendar.DateTime.from_erl!(to_date, "Etc/UTC")
    to = Calendar.DateTime.from_erl!(from_date, "Etc/UTC")
    case Calendar.DateTime.diff(from, to) do
      {:ok, seconds, _, :after} -> seconds
      _ -> 1
    end
  end

  defp generate_exid(title) when title in ["", nil], do: nil
  defp generate_exid(title) do
    clip_exid =
      title
      |> String.replace_trailing(" ", "")
      |> String.downcase
      |> String.slice(0..5)

    random_string = Enum.concat(?a..?z, ?0..?9) |> Enum.take_random(4)
    "#{clip_exid}-#{random_string}"
  end
end
