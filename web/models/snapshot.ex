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
end
