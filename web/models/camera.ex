defmodule Camera do
  use Ecto.Model

  schema "cameras" do
    belongs_to :owner, User, foreign_key: :owner_id
    belongs_to :vendor_model, VendorModel, foreign_key: :model_id
    has_many :camera_shares, CameraShare
    has_many :snapshots, Snapshot
    has_many :apps, App
    has_one :cloud_recordings, CloudRecording

    field :exid, :string
    field :name, :string
    field :timezone, :string
    field :thumbnail_url, :string
    field :is_online, :boolean
    field :is_public, :boolean
    field :is_online_email_owner_notification, :boolean
    field :config, EvercamMedia.Types.JSON
    field :last_polled_at, Ecto.DateTime, default: Ecto.DateTime.utc
    field :last_online_at, Ecto.DateTime, default: Ecto.DateTime.utc
    field :updated_at, Ecto.DateTime, default: Ecto.DateTime.utc
    field :created_at, Ecto.DateTime, default: Ecto.DateTime.utc
  end

  def get_vendor_exid_by_camera_exid(camera_id) do
    EvercamMedia.Repo.one from c in Camera,
    join: vm in assoc(c, :vendor_model),
    join: v in assoc(vm, :vendor),
    where: c.exid == ^camera_id,
    select: v.exid
  end

  def get_all do
    EvercamMedia.Repo.all from c in Camera,
    full_join: vm in assoc(c, :vendor_model),
    full_join: v in assoc(vm, :vendor),
    preload: :cloud_recordings,
    preload: :vendor_model,
    preload: [vendor_model: :vendor]
  end

  def by_exid(camera_id) do
    from cam in Camera,
    where: cam.exid == ^camera_id,
    select: cam
  end

  def by_exid_with_vendor(camera_id) do
    from cam in Camera,
    where: cam.exid == ^camera_id,
    select: cam,
    preload: :cloud_recordings,
    preload: :vendor_model,
    preload: [vendor_model: :vendor]
  end

  def by_exid_with_owner(camera_id) do
    from cam in Camera,
    where: cam.exid == ^camera_id,
    select: cam,
    preload: :owner
  end

  def by_id_with_owner(camera_id) do
    from cam in Camera,
    where: cam.id == ^camera_id,
    select: cam,
    preload: :owner
  end

  def limit(count) do
    from cam in Camera,
    limit: ^count
  end

  def external_url(camera, type \\ "http") do
    host = camera.config["external_host"] |> to_string
    port = camera.config["external_#{type}_port"] |> to_string
    camera_url(host, port, type)
  end

  defp camera_url("", _port, _type) do
    nil
  end

  defp camera_url(host, "", type) do
    "#{type}://#{host}"
  end

  defp camera_url(host, port, type) do
    "#{type}://#{host}:#{port}"
  end

  def auth(camera) do
    "#{camera.config["auth"]["basic"]["username"]}:#{camera.config["auth"]["basic"]["password"]}"
  end

  def username(camera) do
    "#{camera.config["auth"]["basic"]["username"]}"
  end

  def password(camera) do
    "#{camera.config["auth"]["basic"]["password"]}"
  end

  def res_url(camera, type \\ "jpg") do
    url = "#{camera.config["snapshots"][type]}"
    if String.starts_with?(url, "/") || String.length(url) == 0 do
      "#{url}"
    else
      "/#{url}"
    end
  end

  def snapshot_url(camera) do
    "#{external_url(camera)}#{res_url(camera)}"
  end

  def get_camera_info(camera_id) do
    camera = EvercamMedia.Repo.one! by_exid(camera_id)
    %{
      "url" => external_url(camera),
      "auth" => auth(camera)
    }
  end

  def schedule(cloud_recording) do
    if cloud_recording == nil || cloud_recording.status == "off" do
      %{}
    else
      cloud_recording.schedule
    end
  end

  def initial_sleep(cloud_recording) do
    if cloud_recording == nil || cloud_recording.frequency == 1 || cloud_recording.status == "off" do
      :crypto.rand_uniform(1, 60) * 1000
    else
      1000
    end
  end

  def sleep(cloud_recording) do
    if cloud_recording == nil || cloud_recording.status == "off" do
      60_000
    else
      div(60_000, cloud_recording.frequency)
    end
  end
end
