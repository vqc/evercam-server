defmodule Snapshot do
  use Calendar
  use EvercamMedia.Web, :model
  import Ecto.Query
  alias EvercamMedia.SnapshotRepo

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

  def by_id(snapshot_id) do
    Snapshot
    |> where(snapshot_id: ^snapshot_id)
    |> SnapshotRepo.one
  end

  def latest(camera_id) do
    Snapshot
    |> where([snap], snap.snapshot_id > ^"#{camera_id}_2000")
    |> where([snap], snap.snapshot_id < ^"#{camera_id}_2099")
    |> SnapshotRepo.last
  end

  def delete_by_range(camera_id, [start, finish]) do
    Snapshot
    |> where([snap], snap.snapshot_id > ^"#{camera_id}_#{start}")
    |> where([snap], snap.snapshot_id < ^"#{camera_id}_#{finish}")
    |> SnapshotRepo.delete_all
  end

  def expired(cloud_recording) do
    expired(cloud_recording.camera_id, cloud_recording.storage_duration)
  end

  def expired(_camera_id, -1), do: [[], []]
  def expired(camera_id, storage_duration) do
    seconds_to_expired_day = (storage_duration + 1) * (24 * 60 * 60) * (-1)
    expired_day =
      DateTime.now_utc
      |> DateTime.advance!(seconds_to_expired_day)
    begin_timestamp =
      expired_day
      |> Strftime.strftime!("%Y%m%d")
      |> String.ljust(14, ?0)
    end_timestamp =
      expired_day
      |> Date.next_day!
      |> Strftime.strftime!("%Y%m%d")
      |> String.ljust(14, ?0)
    any_snapshot =
      Snapshot
      |> where([snap], snap.snapshot_id > ^"#{camera_id}_#{begin_timestamp}")
      |> where([snap], snap.snapshot_id < ^"#{camera_id}_#{end_timestamp}")
      |> where([snap], snap.notes == "Evercam Proxy")
      |> limit(1)
      |> SnapshotRepo.one
    kept_snapshots =
      Snapshot
      |> where([snap], snap.snapshot_id > ^"#{camera_id}_#{begin_timestamp}")
      |> where([snap], snap.snapshot_id < ^"#{camera_id}_#{end_timestamp}")
      |> where([snap], snap.notes != "Evercam Proxy")
      |> SnapshotRepo.all

    cond do
      any_snapshot == nil ->
        [[], []]
      kept_snapshots == [] ->
        [[begin_timestamp, end_timestamp]]
      true ->
        construct_ranges(camera_id, kept_snapshots, begin_timestamp, end_timestamp)
    end
  end

  defp construct_ranges(camera_id, snapshots, start, finish) do
    snapshots = Enum.map(snapshots, fn(s) -> String.replace(s.snapshot_id, "#{camera_id}_", "") end)
    []
    |> Enum.into([finish])
    |> Enum.into(snapshots)
    |> Enum.into([start])
    |> Enum.chunk(2, 1)
  end

  def changeset(snapshot, params \\ :invalid) do
    snapshot
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:snapshot_id, name: :snapshots_pkey)
  end
end
