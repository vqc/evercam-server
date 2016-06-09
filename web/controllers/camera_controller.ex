defmodule EvercamMedia.CameraController do
  use EvercamMedia.Web, :controller
  alias EvercamMedia.CameraView
  alias EvercamMedia.ErrorView
  alias EvercamMedia.Snapshot.Storage
  alias EvercamMedia.Snapshot.WorkerSupervisor
  alias EvercamMedia.Util
  require Logger
  import String, only: [to_integer: 1]

  def port_check(conn, params) do
    case check_params(params) do
      {:invalid, message} ->
        json(conn, %{error: message})
      :ok ->
        response = %{
          address: params["address"],
          port: to_integer(params["port"]),
          open: Util.port_open?(params["address"], params["port"])
        }
        json(conn, response)
    end
  end

  def index(conn, params) do
    requester = conn.assigns[:current_user]

    if requester do
      requested_user =
        case requester do
          %User{} -> requester
          %AccessToken{} -> User.by_username(params["user_id"])
        end

      include_shared? =
        case params["include_shared"] do
          "false" -> false
          "true" -> true
          _ -> true
        end

      data = ConCache.get_or_store(:cameras, "#{requested_user.username}_#{include_shared?}", fn() ->
        cameras = Camera.for(requested_user, include_shared?)
        Phoenix.View.render(CameraView, "index.json", %{cameras: cameras, user: requester})
      end)

      json(conn, data)
    else
      conn
      |> put_status(404)
      |> render(ErrorView, "error.json", %{message: "Not found."})
    end
  end

  def show(conn, params) do
    current_user = conn.assigns[:current_user]
    camera =
      params["id"]
      |> String.replace_trailing(".json", "")
      |> Camera.get_full

    if Permission.Camera.can_list?(current_user, camera) do
      conn
      |> render("show.json", %{camera: camera, user: current_user})
    else
      conn
      |> put_status(404)
      |> render(ErrorView, "error.json", %{message: "Not found."})
    end
  end

  def transfer(conn, %{"id" => exid, "user_id" => user_id}) do
    current_user = conn.assigns[:current_user]
    camera = Camera.get_full(exid)
    user = User.by_username(user_id)

    with :ok <- is_authorized(conn, current_user),
         :ok <- camera_exists(conn, exid, camera),
         :ok <- user_exists(conn, user_id, user),
         :ok <- has_rights(conn, current_user, camera)
    do
      old_owner = camera.owner
      CameraShare.delete_share(user, camera)
      camera = change_camera_owner(user, camera)
      rights = CameraShare.generate_rights_list("full")
      CameraShare.create_share(camera, old_owner, user, rights)
      update_camera_worker(camera.exid)
      conn
      |> render("show.json", %{camera: camera, user: current_user})
    end
  end

  def thumbnail(conn, %{"id" => exid, "timestamp" => iso_timestamp, "token" => token}) do
    try do
      [token_exid, token_timestamp] = Util.decode(token)
      if exid != token_exid, do: raise "Invalid token."
      if iso_timestamp != token_timestamp, do: raise "Invalid token."

      {:ok, image} = Storage.thumbnail_load(exid)

      conn
      |> put_status(200)
      |> put_resp_header("content-type", "image/jpeg")
      |> text(image)
    rescue
      error ->
        Logger.error "[#{exid}] [thumbnail] [error] [inspect #{error}]"
        send_resp(conn, 500, "Invalid token.")
    end
  end

  def touch(conn, %{"id" => exid, "token" => token}) do
    try do
      [token_exid, _timestamp] = Util.decode(token)
      if exid != token_exid, do: raise "Invalid token."

      Logger.info "Camera update for #{exid}"
      update_camera_worker(exid)
      send_resp(conn, 200, "Camera update request received.")
    rescue
      error ->
        Logger.error "Camera update for #{exid} with error: #{inspect error}"
        send_resp(conn, 500, "Invalid token.")
    end
  end

  defp check_params(params) do
    with :ok <- validate("address", params["address"]),
         :ok <- validate("port", params["port"]),
         do: :ok
  end

  defp validate(key, value) when value in [nil, ""], do: invalid(key)

  defp validate("address", value) do
    if valid?("ip_address", value) || valid?("domain", value), do: :ok, else: invalid("address")
  end

  defp validate("port", value) when is_integer(value) and value >= 1 and value <= 65535, do: :ok
  defp validate("port", value) when is_binary(value) do
    case Integer.parse(value) do
      {int_value, ""} -> validate("port", int_value)
      _ -> invalid("port")
    end
  end
  defp validate("port", _), do: invalid("port")

  defp valid?("ip_address", value) do
    case :inet_parse.strict_address(to_char_list(value)) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  defp valid?("domain", value) do
    :inet_parse.domain(to_char_list(value)) && String.contains?(value, ".")
  end

  defp invalid(key), do: {:invalid, "The parameter '#{key}' isn't valid."}

  defp is_authorized(conn, nil) do
    conn
    |> put_status(401)
    |> render(ErrorView, "error.json", %{message: "Unauthorized."})
  end
  defp is_authorized(_conn, _user), do: :ok

  defp camera_exists(conn, camera_exid, nil) do
    conn
    |> put_status(404)
    |> render(ErrorView, "error.json", %{message: "The #{camera_exid} camera does not exist."})
  end
  defp camera_exists(_conn, _camera_exid, _camera), do: :ok

  defp user_exists(conn, user_id, nil) do
    conn
    |> put_status(404)
    |> render(ErrorView, "error.json", %{message: "User '#{user_id}' does not exist."})
  end
  defp user_exists(_conn, _user_id, _user), do: :ok

  defp has_rights(conn, user, camera) do
    if Camera.is_owner?(user, camera) do
      :ok
    else
      conn
      |> put_status(403)
      |> render(ErrorView, "error.json", %{message: "Unauthorized."})
    end
  end

  defp update_camera_worker(exid) do
    exid |> Camera.get_full |> Camera.invalidate_camera
    camera = exid |> Camera.get_full

    exid
    |> String.to_atom
    |> Process.whereis
    |> WorkerSupervisor.update_worker(camera)
  end

  defp change_camera_owner(user, camera) do
    camera
    |> Camera.changeset(%{owner_id: user.id})
    |> Repo.update!
    |> Repo.preload(:owner, force: true)
  end
end
