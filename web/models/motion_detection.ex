defmodule MotionDetection do
  use EvercamMedia.Web, :model
  alias EvercamMedia.Repo
  import Ecto.Query

  schema "motion_detections" do
    belongs_to :camera, Camera, foreign_key: :camera_id

    field :enabled, :boolean
  end

  def enabled?(camera) do
    camera = Repo.preload(camera, :motion_detections)
    if camera.motion_detections, do: camera.motion_detections.enabled, else: false
  end

  def delete_by_camera_id(camera_id) do
    MotionDetection
    |> where(camera_id: ^camera_id)
    |> Repo.delete_all
  end
end
