defmodule CameraActivity do
  use Ecto.Model

  @required_fields ~w(camera_id)
  @optional_fields ~w(action done_at)

  schema "camera_activities" do
    belongs_to :camera, Camera

    field :action, :string
    field :done_at, Ecto.DateTime, default: Ecto.DateTime.utc
  end

  def changeset(camera_activity, params \\ :empty) do
    camera_activity
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:camera_id, name: :camera_activities_camera_id_done_at_index)
  end
end
