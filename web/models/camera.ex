defmodule Camera do
  use EvercamMedia.Web, :model
  import Ecto.Changeset
  import Ecto.Query
  alias EvercamMedia.Repo
  alias EvercamMedia.Schedule

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
    field :config, EvercamMedia.Types.JSON
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
    |> where([cam], cam.exid == ^exid)
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

  def get_vendor_exid(camera_full) do
    case camera_full.vendor_model do
      nil -> ""
      vendor_model -> vendor_model.vendor.exid
    end
  end

  def get_camera_info(exid) do
    camera = Camera.get(exid)
    %{
      "url" => external_url(camera),
      "auth" => auth(camera)
    }
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
