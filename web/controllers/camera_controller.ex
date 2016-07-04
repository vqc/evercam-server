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
      rights = CameraShare.rights_list("full") |> Enum.join(",")
      CameraShare.create_share(camera, old_owner, user, rights)
      update_camera_worker(camera.exid)
      conn
      |> render("show.json", %{camera: camera, user: current_user})
    end
  end

  def update(conn, %{"id" => exid} = params) do
    caller = conn.assigns[:current_user]
    camera =
      exid
      |> String.downcase
      |> Camera.get_full

    with :ok <- camera_exists(conn, exid, camera),
         :ok <- user_has_rights(conn, caller, camera)
    do
      camera_changeset = update_camera(camera, params)
      case Repo.update(camera_changeset) do
        {:ok, camera} ->
          Camera.invalidate_camera(camera)
          camera = Camera.get_full(camera.exid)
          CameraActivity.log_activity(caller, camera, "edited")
          conn
          |> render("show.json", %{camera: camera, user: caller})
        {:error, changeset} ->
          render_error(conn, 400, Util.parse_changeset(changeset))
      end
    end
  end

  def delete(conn, %{"id" => exid}) do
    caller = conn.assigns[:current_user]
    camera = exid |> String.downcase |> Camera.get_full

    with :ok <- camera_exists(conn, exid, camera),
         true <- user_has_delete_rights(conn, caller, camera)
    do
      admin_user = User.by_username_or_email("admin@evercam.io")
      camera_params = %{
        owner_id: admin_user.id,
        discoverable: false,
        is_public: false
      }
      camera
      |> Camera.changeset(camera_params)
      |> Repo.update!
      |> Camera.invalidate_camera

      spawn(fn -> delete_camera_worker(camera.id) end)
      spawn(fn -> delete_snapshot_worker(camera.id) end)
      json(conn, %{})
    end
  end

  def create(conn, params) do
    caller = conn.assigns[:current_user]

    with :ok <- is_authorized(conn, caller)
    do
      params = is_public(params, params["is_public"])
      params = Map.merge(%{"owner_id" => caller.id}, params)
      camera_changeset = create_camera(params)
      case Repo.insert(camera_changeset) do
        {:ok, camera} ->
          full_camera =
            camera
            |> Repo.preload(:owner, force: true)
            |> Repo.preload(:cloud_recordings, force: true)
            |> Repo.preload(:vendor_model, force: true)
            |> Repo.preload([vendor_model: :vendor], force: true)
          CameraActivity.log_activity(caller, camera, "created")
          conn
          |> render("show.json", %{camera: full_camera, user: caller})
        {:error, changeset} ->
          render_error(conn, 400, Util.parse_changeset(changeset))
      end
    end
  end

  def thumbnail(conn, %{"id" => exid, "timestamp" => iso_timestamp, "token" => token}) do
    try do
      [token_exid, token_timestamp] = Util.decode(token)
      if exid != token_exid, do: raise "Invalid token."
      if iso_timestamp != token_timestamp, do: raise "Invalid token."

      case Storage.thumbnail_load(exid) do
        {:ok, snapshot} ->
          conn
          |> put_resp_header("content-type", "image/jpeg")
          |> text(snapshot)
        {:error, error_image} ->
          conn
          |> put_status(404)
          |> put_resp_header("content-type", "image/jpeg")
          |> text(error_image)
      end
    rescue
      error ->
        Logger.error "[#{exid}] [thumbnail] [error] [#{inspect error}]"
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
    if Camera.valid?("address", value), do: :ok, else: invalid("address")
  end

  defp validate("port", value) when is_integer(value) and value >= 1 and value <= 65_535, do: :ok
  defp validate("port", value) when is_binary(value) do
    case Integer.parse(value) do
      {int_value, ""} -> validate("port", int_value)
      _ -> invalid("port")
    end
  end
  defp validate("port", _), do: invalid("port")

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

  defp user_has_rights(conn, user, camera) do
    if !Permission.Camera.can_edit?(user, camera) do
      conn
      |> put_status(403)
      |> render(ErrorView, "error.json", %{message: "Unauthorized."})
    else
      :ok
    end
  end

  defp user_has_delete_rights(conn, user, camera) do
    if !Permission.Camera.can_delete?(user, camera) do
      conn
      |> put_status(403)
      |> render(ErrorView, "error.json", %{message: "Unauthorized."})
    else
      true
    end
  end

  defp update_camera(camera, params) do
    model = VendorModel.get_model(params["vendor"], params["model"])

    camera_params = %{config: Map.get(camera, :config)}
    camera_params = add_parameter("field", camera_params, :name, params["name"])
    camera_params = add_parameter("field", camera_params, :timezone, params["timezone"])
    camera_params = add_parameter("field", camera_params, :mac_address, params["mac_address"])
    camera_params = add_parameter("field", camera_params, :is_online, params["is_online"])
    camera_params = add_parameter("field", camera_params, :is_public, params["is_public"])
    camera_params = add_parameter("field", camera_params, :discoverable, params["discoverable"])
    camera_params = add_parameter("field", camera_params, :is_online_email_owner_notification, params["is_online_email_owner_notification"])
    camera_params = add_parameter("field", camera_params, :location_lng, params["location_lng"])
    camera_params = add_parameter("field", camera_params, :location_lat, params["location_lat"])

    camera_params = add_parameter("model", camera_params, :model_id, model)

    camera_params = add_parameter("host", camera_params, "external_host", params["external_host"])
    camera_params = add_parameter("host", camera_params, "external_http_port", params["external_http_port"])
    camera_params = add_parameter("host", camera_params, "external_rtsp_port", params["external_rtsp_port"])

    camera_params = add_parameter("host", camera_params, "internal_host", params["internal_host"])
    camera_params = add_parameter("host", camera_params, "internal_http_port", params["internal_http_port"])
    camera_params = add_parameter("host", camera_params, "internal_rtsp_port", params["internal_rtsp_port"])

    camera_params = add_parameter("url", camera_params, "jpg", params["jpg_url"])
    camera_params = add_parameter("url", camera_params, "mjpg", params["mjpg_url"])
    camera_params = add_parameter("url", camera_params, "h264", params["h264_url"])
    camera_params = add_parameter("url", camera_params, "audio", params["audio_url"])
    camera_params = add_parameter("url", camera_params, "mpeg", params["mpeg_url"])

    camera_params = add_parameter("auth", camera_params, "username", params["cam_username"])
    camera_params = add_parameter("auth", camera_params, "password", params["cam_password"])

    Camera.changeset(camera, camera_params)
  end

  defp create_camera(params) do
    model = VendorModel.get_model(params["vendor"], params["model"])

    camera_params = %{
      name: params["name"],
      owner_id: params["owner_id"],
      is_public: params["is_public"],
      config: %{
        "external_host" => params["external_host"],
        "snapshots" => %{}
      }
    }

    camera_params = add_parameter("field", camera_params, :exid, params["id"])
    camera_params = add_parameter("field", camera_params, :timezone, params["timezone"])
    camera_params = add_parameter("field", camera_params, :mac_address, params["mac_address"])
    camera_params = add_parameter("field", camera_params, :is_online, params["is_online"])
    camera_params = add_parameter("field", camera_params, :discoverable, params["discoverable"])
    camera_params = add_parameter("field", camera_params, :is_online_email_owner_notification, params["is_online_email_owner_notification"])
    camera_params = add_parameter("field", camera_params, :location_lng, params["location_lng"])
    camera_params = add_parameter("field", camera_params, :location_lat, params["location_lat"])

    camera_params = add_parameter("model", camera_params, :model_id, model)
    camera_params = add_parameter("host", camera_params, "external_http_port", params["external_http_port"])
    camera_params = add_parameter("host", camera_params, "external_rtsp_port", params["external_rtsp_port"])

    camera_params = add_parameter("host", camera_params, "internal_host", params["internal_host"])
    camera_params = add_parameter("host", camera_params, "internal_http_port", params["internal_http_port"])
    camera_params = add_parameter("host", camera_params, "internal_rtsp_port", params["internal_rtsp_port"])

    camera_params = add_parameter("url", camera_params, "jpg", params["jpg_url"])
    camera_params = add_parameter("url", camera_params, "mjpg", params["mjpg_url"])
    camera_params = add_parameter("url", camera_params, "h264", params["h264_url"])
    camera_params = add_parameter("url", camera_params, "audio", params["audio_url"])
    camera_params = add_parameter("url", camera_params, "mpeg", params["mpeg_url"])

    camera_params = add_parameter("auth", camera_params, "username", params["cam_username"])
    camera_params = add_parameter("auth", camera_params, "password", params["cam_password"])

    Camera.changeset(%Camera{}, camera_params)
  end

  defp is_public(params, value) when value in [nil, ""], do: Map.merge(%{"is_public" => "false"}, params)
  defp is_public(params, _value), do: params

  defp add_parameter(_field, params, _key, value) when value in [nil, ""], do: params
  defp add_parameter("field", params, key, value) do
    Map.put(params, key, value)
  end
  defp add_parameter("model", params, key, value) do
    Map.put(params, key, value.id)
  end
  defp add_parameter("host", params, key, value) do
    put_in(params, [:config, key], value)
  end
  defp add_parameter("url", params, key, value) do
    put_in(params, [:config, "snapshots", key], value)
  end
  defp add_parameter("auth", params, key, value) do
    put_in(params, [:config, "auth", "basic", key], value)
  end

  defp delete_camera_worker(camera_id) do
    CloudRecording.delete_by_camera_id(camera_id)
    MotionDetection.delete_by_camera_id(camera_id)
    CameraShare.delete_by_camera_id(camera_id)
    CameraShareRequest.delete_by_camera_id(camera_id)
    Camera.delete_by_id(camera_id)
  end

  defp delete_snapshot_worker(camera_id) do
    CameraActivity.delete_by_camera_id(camera_id)
    Snapshot.delete_by_camera_id(camera_id)
    # TODO Seaweedfs Deletion
  end
end
