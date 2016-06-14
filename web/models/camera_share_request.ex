defmodule CameraShareRequest do
  use EvercamMedia.Web, :model
  import Ecto.Query
  alias EvercamMedia.Repo

  @status %{pending: -1, cancelled: -2, used: 1}

  schema "camera_share_requests" do
    belongs_to :camera, Camera
    belongs_to :user, User

    field :key, :string
    field :email, :string
    field :rights, :string
    field :status, :integer
    timestamps(inserted_at: :created_at, type: Ecto.DateTime, default: Ecto.DateTime.utc)
  end

  def by_camera_and_status(camera, nil) do
    CameraShareRequest
    |> where(camera_id: ^camera.id)
    |> preload(:camera)
    |> preload(:user)
    |> Repo.all
  end

  def by_camera_and_status(camera, status) do
    CameraShareRequest
    |> where(camera_id: ^camera.id)
    |> where(status: ^status)
    |> preload(:camera)
    |> preload(:user)
    |> Repo.all
  end

  def get_status(status) do
    case status do
      "used" -> @status.used
      "cancelled" -> @status.cancelled
      "pending" -> @status.pending
    end
  end
end
