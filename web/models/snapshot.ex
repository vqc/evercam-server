defmodule Snapshot do
  use Ecto.Model

  @primary_key {:snapshot_id, :string, autogenerate: false}
  schema "snapshots" do
    belongs_to :camera, Camera, references: :snapshot_id

    field :notes, :string
    field :motionlevel, :integer
    field :created_at, Ecto.DateTime, default: Ecto.DateTime.utc
  end

  def for_camera(camera_id) do
    from snap in Snapshot,
      where: snap.camera_id == ^camera_id,
      select: snap
  end

  def expired_by_cloud_recording(cloud_recording) do
    seconds_to_expired_day = cloud_recording.storage_duration * 24 * 60 * 60 * -1
    expired_day = Calendar.DateTime.now_utc |> Calendar.DateTime.advance!(seconds_to_expired_day)
    begin_timestamp = expired_day |> Calendar.Strftime.strftime! "%Y%m%d"
    end_timestamp = expired_day |> Calendar.Date.next_day! |> Calendar.Strftime.strftime! "%Y%m%d"

    from snap in Snapshot,
      where: snap.snapshot_id > "#{cloud_recording.camera_id}_#{begin_timestamp}",
      where: snap.snapshot_id < "#{cloud_recording.camera_id}_#{end_timestamp}",
      where: snap.notes == "Evercam Proxy"
  end
end
