defmodule CloudRecording do
  use Ecto.Model
  import Ecto.Query
  alias EvercamMedia.Repo

  schema "cloud_recordings" do
    belongs_to :camera, Camera, foreign_key: :camera_id

    field :frequency, :integer
    field :storage_duration, :integer
    field :status, :string
    field :schedule, EvercamMedia.Types.JSON
  end

  def get_all do
    CloudRecording
    |> preload(:camera)
    |> Repo.all
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
