defmodule CameraActivity do
  use EvercamMedia.Web, :model
  import Ecto.Changeset
  import Ecto.Query
  alias EvercamMedia.SnapshotRepo

  @required_fields ~w(camera_id)
  @optional_fields ~w(action done_at)

  schema "camera_activities" do
    belongs_to :camera, Camera
    belongs_to :access_token, AccessToken

    field :action, :string
    field :done_at, Ecto.DateTime, default: Ecto.DateTime.utc
    field :extra, EvercamMedia.Types.JSON
    field :camera_exid, :string
    field :name, :string
  end

  def min_date do
    CameraActivity
    |> select([c], min(c.done_at))
    |> SnapshotRepo.one
  end

  def changeset(camera_activity, params \\ :invalid) do
    camera_activity
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:camera_id, name: :camera_activities_camera_id_done_at_index)
  end
end
