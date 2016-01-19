defmodule Snapshot do
  alias Calendar.Date
  alias Calendar.DateTime
  alias Calendar.Strftime
  alias EvercamMedia.SnapshotRepo
  use Ecto.Model

  @required_fields ~w(snapshot_id camera_id)
  @optional_fields ~w(notes motionlevel created_at is_public)

  @primary_key {:snapshot_id, :string, autogenerate: false}

  schema "snapshots" do
    belongs_to :camera, Camera, references: :snapshot_id

    field :notes, :string
    field :is_public, :boolean
    field :motionlevel, :integer
    field :created_at, Ecto.DateTime, default: Ecto.DateTime.utc
  end

  def for_camera(camera_id) do
    from snap in Snapshot,
      where: snap.camera_id == ^camera_id,
      select: snap
  end

  def expired(cloud_recording) do
    expired(cloud_recording.camera_id, cloud_recording.storage_duration)
  end

  defp expired(_camera_id, -1) do
    []
  end

  defp expired(camera_id, storage_duration) do
    seconds_to_expired_day = (storage_duration + 1) * (24 * 60 * 60) * (-1)
    expired_day = DateTime.now_utc |> DateTime.advance!(seconds_to_expired_day)
    begin_timestamp = expired_day |> Strftime.strftime! "%Y%m%d"
    end_timestamp = expired_day |> Date.next_day! |> Strftime.strftime! "%Y%m%d"

    snapshots =
      from(snap in Snapshot,
        where: snap.snapshot_id > ^"#{camera_id}_#{begin_timestamp}",
        where: snap.snapshot_id < ^"#{camera_id}_#{end_timestamp}",
        where: snap.notes == "Evercam Proxy")

    SnapshotRepo.all(snapshots)
  end

  def changeset(snapshot, params \\ :empty) do
    snapshot
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:snapshot_id, name: :snapshots_pkey)
  end
end
