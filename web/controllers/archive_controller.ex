defmodule EvercamMedia.ArchiveController do
  use EvercamMedia.Web, :controller
  alias EvercamMedia.ArchiveView

  def index(conn, %{"id" => exid} = params) do
    current_user = conn.assigns[:current_user]
    camera = Camera.by_exid_with_associations(exid)
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

  def delete(conn, %{"id" => exid, "archive_id" => archive_id} = params) do
    current_user = conn.assigns[:current_user]
    camera = Camera.by_exid_with_associations(exid)

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
end
