defmodule CameraShare do
  use EvercamMedia.Web, :model

  schema "camera_shares" do
    belongs_to :camera, Camera
    belongs_to :user, User
  end
end
