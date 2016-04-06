defmodule Camera do
  use EvercamMedia.Web, :model
  import Ecto.Changeset
  import Ecto.Query
  alias EvercamMedia.Repo
  alias EvercamMedia.Schedule
  alias EvercamMedia.Util

  @required_fields ~w(exid name owner_id config is_public is_online_email_owner_notification)
  @optional_fields ~w(timezone thumbnail_url is_online last_polled_at last_online_at updated_at created_at)

  schema "cameras" do
    belongs_to :owner, User, foreign_key: :owner_id
    belongs_to :vendor_model, VendorModel, foreign_key: :model_id
    has_many :shares, CameraShare
    has_many :snapshots, Snapshot
    has_one :cloud_recordings, CloudRecording
    has_one :motion_detections, MotionDetection

    field :exid, :string
    field :name, :string
    field :timezone, :string
    field :thumbnail_url, :string
    field :is_online, :boolean
    field :is_public, :boolean
    field :is_online_email_owner_notification, :boolean, default: false
    field :discoverable, :boolean, default: false
    field :config, EvercamMedia.Types.JSON
    field :mac_address, EvercamMedia.Types.MACADDR
    field :location, Geo.Point
    field :last_polled_at, Ecto.DateTime, default: Ecto.DateTime.utc
    field :last_online_at, Ecto.DateTime, default: Ecto.DateTime.utc
    field :updated_at, Ecto.DateTime, default: Ecto.DateTime.utc
    field :created_at, Ecto.DateTime, default: Ecto.DateTime.utc
  end

  def get_all do
    Camera
    |> join(:full, [c], vm in assoc(c, :vendor_model))
    |> join(:full, [c, vm], v in assoc(vm, :vendor))
    |> preload(:cloud_recordings)
    |> preload(:motion_detections)
    |> preload(:vendor_model)
    |> preload([vendor_model: :vendor])
    |> Repo.all
  end

  def get(exid) do
    ConCache.dirty_get_or_store(:camera, exid, fn() ->
      Camera.by_exid(exid)
    end)
  end

  def get_full(exid) do
    ConCache.dirty_get_or_store(:camera_full, exid, fn() ->
      Camera.by_exid_with_associations(exid)
    end)
  end

  def by_exid(exid) do
    Camera
    |> where(exid: ^exid)
    |> Repo.first
  end

  def by_exid_with_associations(exid) do
    Camera
    |> where([cam], cam.exid == ^exid)
    |> preload(:cloud_recordings)
    |> preload(:motion_detections)
    |> preload(:owner)
    |> preload(:vendor_model)
    |> preload([vendor_model: :vendor])
    |> Repo.first
  end

  def auth(camera) do
    username(camera) <> ":" <> password(camera)
  end

  def username(camera) do
    "#{camera.config["auth"]["basic"]["username"]}"
  end

  def password(camera) do
    "#{camera.config["auth"]["basic"]["password"]}"
  end

  def snapshot_url(camera) do
    external_url(camera) <> res_url(camera)
  end

  defp external_url(camera, type \\ "http") do
    host = camera.config["external_host"] |> to_string
    port = camera.config["external_#{type}_port"] |> to_string
    case {host, port} do
      {"", _} -> ""
      {host, ""} -> "#{type}://#{host}"
      {host, port} -> "#{type}://#{host}:#{port}"
    end
  end

  defp res_url(camera, type \\ "jpg") do
    url = "#{camera.config["snapshots"][type]}"
    case String.starts_with?(url, "/") || String.length(url) == 0 do
      true -> "#{url}"
      false -> "/#{url}"
    end
  end

  defp h264_path(camera) do
    cond do
      res_url(camera, "h264") != "" ->
        res_url(camera, "h264")
      res_url(camera, "h264") == "" && get_model_attr(camera, :config) != "" ->
        res_url(camera.vendor_model, "h264")
      true ->
        ""
    end
  end

  defp rtsp_url(camera) do
    h264_path = h264_path(camera)
    host = camera.config["external_host"]
    port = camera.config["external_rtsp_port"]

    case h264_path != "" && host != "" && "#{port}" != "" && "#{port}" != 0 do
      true -> "rtsp://#{auth(camera)}@#{host}:#{port}#{h264_path}"
      false -> ""
    end
  end

  def get_rtmp_url(camera) do
    if rtsp_url(camera) != "" do
      base_url = EvercamMedia.Endpoint.url |> String.replace("http", "rtmp") |> String.replace("4000", "1935")
      base_url <> "/live/" <> streaming_token(camera) <> "?camera_id=" <> camera.exid
    else
      ""
    end
  end

  def get_hls_url(camera) do
    if rtsp_url(camera) != "" do
      base_url = EvercamMedia.Endpoint.url
      base_url <> "/live/" <> streaming_token(camera) <> "/index.m3u8?camera_id="<> camera.exid
    else
      ""
    end
  end

  defp streaming_token(camera) do
    token = username(camera) <> "|" <> password(camera) <> "|" <> rtsp_url(camera)
    Util.encode([token])
  end

  def get_vendor_attr(camera_full, attr) do
    case camera_full.vendor_model do
      nil -> ""
      vendor_model -> Map.get(vendor_model.vendor, attr)
    end
  end

  def get_model_attr(camera_full, attr) do
    case camera_full.vendor_model do
      nil -> ""
      vendor_model -> Map.get(vendor_model, attr)
    end
  end

  def get_timezone(camera) do
    case camera.timezone do
      nil -> "Etc/UTC"
      timezone -> timezone
    end
  end

  def get_location(camera) do
    {lng, lat} =
      case camera.location do
        %Geo.Point{} -> camera.location.coordinates
        _nil -> {0, 0}
      end
    %{lng: lng, lat: lat}
  end

  def get_camera_info(exid) do
    camera = Camera.get(exid)
    %{
      "url" => external_url(camera),
      "auth" => auth(camera)
    }
  end

  def get_rights(camera, user) do
    AccessRight.list(camera, user)
  end

  def recording?(camera_full) do
    !!Application.get_env(:evercam_media, :start_camera_workers)
    && CloudRecording.sleep(camera_full.cloud_recordings) == 1000
    && Schedule.scheduled_now?(camera_full) == {:ok, true}
  end

  def changeset(camera, params \\ :invalid) do
    camera
    |> cast(params, @required_fields, @optional_fields)
  end
end
