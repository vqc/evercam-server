defmodule EvercamMedia.SnapmailController do
  use EvercamMedia.Web, :controller
  alias EvercamMedia.SnapmailView

  def all(conn, _) do
    current_user = conn.assigns[:current_user]

    with :ok <- authorized(conn, current_user)
    do
      snapmails = Snapmail.by_user_id(current_user.id)
      render(conn, SnapmailView, "index.json", %{snapmails: snapmails})
    end
  end

  def index(conn, %{"id" => exid}) do
    current_user = conn.assigns[:current_user]
    camera = Camera.get_full(exid)

    with :ok <- ensure_camera_exists(camera, exid, conn),
         :ok <- ensure_can_list(current_user, camera, conn)
    do
      snapmails = Snapmail.camera_and_user_id(camera.id, current_user.id)
      render(conn, SnapmailView, "index.json", %{snapmails: snapmails})
    end
  end

  def show(conn, %{"id" => exid, "snapmail_id" => snapmail_exid}) do
    current_user = conn.assigns[:current_user]
    camera = Camera.get_full(exid)

    with :ok <- ensure_camera_exists(camera, exid, conn),
         :ok <- ensure_can_list(current_user, camera, conn)
    do
      snapmail = Snapmail.by_exid(snapmail_exid)

      case snapmail do
        nil ->
          render_error(conn, 404, "Snapmail '#{snapmail_exid}' not found!")
        _ ->
          render(conn, SnapmailView, "show.json", %{snapmail: snapmail})
      end
    end
  end

  def create(conn, %{"id" => exid} = params) do
    current_user = conn.assigns[:current_user]
    camera = Camera.get_full(exid)

    with :ok <- ensure_camera_exists(camera, exid, conn)
    do
      changeset =
        params
        |> add_user_id_params(current_user)
        |> snapmail_create_changeset(camera.id)

      case Repo.insert(changeset) do
        {:ok, snapmail} ->
          render(conn |> put_status(:created), SnapmailView, "show.json", %{snapmail: snapmail |> Repo.preload(:camera) |> Repo.preload(:user)})
        {:error, changeset} ->
          render_error(conn, 400, Util.parse_changeset(changeset))
      end
    end
  end

  def update(conn, %{"id" => exid, "snapmail_id" => snapmail_exid} = params) do
    current_user = conn.assigns[:current_user]
    camera = Camera.get_full(exid)

    with :ok <- ensure_camera_exists(camera, exid, conn),
         :ok <- ensure_can_edit(current_user, camera, conn),
         {:ok, snapmail} <- snapmail_exist(conn, snapmail_exid)
    do
      snapmail_params = construct_snapmail_parameters(%{}, params)
      changeset = Snapmail.changeset(snapmail, snapmail_params)
      case Repo.update(changeset) do
        {:ok, snapmail} ->
          render(conn, SnapmailView, "show.json", %{snapmail: snapmail})
        {:error, changeset} ->
          render_error(conn, 400, Util.parse_changeset(changeset))
      end
    end
  end

  def unsubscribe(conn, %{"id" => exid, "snapmail_id" => snapmail_exid, "email" => email}) do
    current_user = conn.assigns[:current_user]
    camera = Camera.get_full(exid)

    with :ok <- ensure_camera_exists(camera, exid, conn),
         :ok <- ensure_can_edit(current_user, camera, conn),
         {:ok, snapmail} <- snapmail_exist(conn, snapmail_exid)
    do
      snapmail_params = %{recipients: remove_email(snapmail.recipients, email)}
      changeset = Snapmail.changeset(snapmail, snapmail_params)
      case Repo.update(changeset) do
        {:ok, snapmail} ->
          render(conn, SnapmailView, "show.json", %{snapmail: snapmail})
        {:error, changeset} ->
          render_error(conn, 400, Util.parse_changeset(changeset))
      end
    end
  end

  def delete(conn, %{"id" => exid, "snapmail_id" => snapmail_exid}) do
    current_user = conn.assigns[:current_user]
    camera = Camera.get_full(exid)

    with :ok <- ensure_camera_exists(camera, exid, conn),
         :ok <- ensure_can_delete(current_user, camera, conn),
         {:ok, _snapmail} <- snapmail_exist(conn, snapmail_exid)
    do
      Snapmail.delete_by_exid(snapmail_exid)
      json(conn, %{})
    end
  end

  defp snapmail_create_changeset(params, camera_id) do
    snapmail_params =
      %{camera_id: camera_id}
      |> construct_snapmail_parameters(params)

    Snapmail.changeset(%Snapmail{}, snapmail_params)
  end

  defp construct_snapmail_parameters(snapmail, params) do
    snapmail
    |> add_parameter(:subject, params["subject"])
    |> add_parameter(:notify_time, params["notify_time"])
    |> add_parameter(:user_id, params["user_id"])
    |> add_parameter(:recipients, params["recipients"])
    |> add_parameter(:message, params["message"])
    |> add_parameter(:notify_days, params["notify_days"])
    |> add_parameter(:is_public, params["is_public"])
  end

  defp add_parameter(params, _key, nil), do: params
  defp add_parameter(params, key, value) do
    Map.put(params, key, value)
  end

  defp add_user_id_params(params, nil) do
    Map.merge(params, %{"is_public" => "true"})
  end
  defp add_user_id_params(params, user) do
    Map.merge(params, %{"user_id" => user.id})
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

  defp ensure_can_edit(nil, _camera, conn), do: render_error(conn, 401, "Unauthorized.")
  defp ensure_can_edit(current_user, camera, conn) do
    if Permission.Camera.can_edit?(current_user, camera) do
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

  defp snapmail_exist(conn, snapmail_exid) do
    case Snapmail.by_exid(snapmail_exid) do
      nil -> render_error(conn, 404, "Snapmail not found.")
      %Snapmail{} = snapmail -> {:ok, snapmail}
    end
  end

  defp remove_email(emails, unsubscribe) do
    emails
    |> String.split(",", trim: true)
    |> Enum.reject(fn(email) -> email == unsubscribe end)
    |> Enum.join(",")
  end

  defp authorized(conn, nil), do: render_error(conn, 401, "Unauthorized.")
  defp authorized(_conn, _current_user), do: :ok
end
