defmodule CameraShareRequest do
  use EvercamMedia.Web, :model
  import Ecto.Query
  alias EvercamMedia.Repo

  @required_fields ~w(camera_id user_id key email status rights)
  @optional_fields ~w(message created_at updated_at)
  @status %{pending: -1, cancelled: -2, used: 1}

  schema "camera_share_requests" do
    belongs_to :camera, Camera
    belongs_to :user, User

    field :key, :string
    field :email, :string
    field :rights, :string
    field :status, :integer
    field :message, :string
    timestamps(inserted_at: :created_at, type: Ecto.DateTime, default: Ecto.DateTime.utc)
  end

  def status, do: @status

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

  def get_pending_request(camera_id, email) do
    CameraShareRequest
    |> where(camera_id: ^camera_id)
    |> where(status: ^@status.pending)
    |> where(email: ^email)
    |> Repo.one
  end

  def get_status(status) do
    case status do
      "used" -> @status.used
      "cancelled" -> @status.cancelled
      "pending" -> @status.pending
    end
  end

  def create_share_request(camera, email, sharer, rights, message) do
    share_request_params = %{
      camera_id: camera.id,
      user_id: sharer.id,
      status: status.pending,
      email: email,
      rights: rights,
      message: message,
      key: UUID.uuid4(:hex)
    }
    changeset = changeset(%CameraShareRequest{}, share_request_params)
    case Repo.insert(changeset) do
      {:ok, share_request} ->
        camera_share_request =
          share_request
          |> Repo.preload(:camera)
          |> Repo.preload(:user)
        {:ok, camera_share_request}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp validate_rights(changeset, field) do
    rights = get_field(changeset, field)
    if rights do
      access_rights =
        rights
        |> CameraShare.to_rights_list
        |> Enum.join(",")
      if rights == access_rights do
        changeset
      else
        add_error(changeset, field, "Invalid rights specified in request.")
      end
    else
      add_error(changeset, field, "Invalid rights specified in request.")
    end
  end

  defp share_request_exist(changeset, camera_field, email_field) do
    camera_id = get_field(changeset, camera_field)
    email = get_field(changeset, email_field)
    case get_pending_request(camera_id, email) do
      nil -> changeset
      %CameraShareRequest{} -> add_error(changeset, email_field, "A share request already exists for the '#{email}' email address for this camera.")
    end
  end

  def changeset(model, params \\ :invalid) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> validate_required(:email)
    |> validate_format(:email, ~r/\A.+\@.+\..+\z/, [message: "You've entered an invalid email address."])
    |> validate_rights(:rights)
    |> share_request_exist(:camera_id, :email)
  end
end
