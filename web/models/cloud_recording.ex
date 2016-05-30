defmodule CloudRecording do
  use EvercamMedia.Web, :model
  import Ecto.Query
  alias EvercamMedia.Repo

  @required_fields ~w(camera_id frequency storage_duration status schedule)

  schema "cloud_recordings" do
    belongs_to :camera, Camera, foreign_key: :camera_id

    field :frequency, :integer
    field :storage_duration, :integer
    field :status, :string
    field :schedule, EvercamMedia.Types.JSON
  end

  def get_all_ephemeral do
    CloudRecording
    |> where([cl], cl.storage_duration != -1)
    |> preload(:camera)
    |> Repo.all
  end

  def cloud_recording(camera_id) do
    CloudRecording
    |> where(camera_id: ^camera_id)
    |> Repo.first
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

  def changeset(model, params \\ :invalid) do
    model
    |> cast(params, @required_fields)
  end
end
