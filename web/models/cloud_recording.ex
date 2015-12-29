defmodule CloudRecording do
  use Ecto.Model

  schema "cloud_recordings" do
    belongs_to :camera, Camera, foreign_key: :camera_id

    field :frequency, :integer
    field :storage_duration, :integer
    field :status, :string
    field :schedule, EvercamMedia.Types.JSON
  end

  def get_all do
    EvercamMedia.Repo.all from cl in CloudRecording,
    preload: :camera
  end
end
