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

  def get_sharer_email(share_request) do
    if share_request.user, do: share_request.user.email, else: ""
  end

  def get_sharer_username(share_request) do
    if share_request.user, do: share_request.user.username, else: ""
  end

  def get_sharer_fullname(share_request) do
    if share_request.user, do: "#{share_request.user.firstname} #{share_request.user.lastname}", else: ""
  end

  def get_status(status) do
    case status do
      "used" -> @status.used
      "cancelled" -> @status.cancelled
      "pending" -> @status.pending
    end
  end
end
