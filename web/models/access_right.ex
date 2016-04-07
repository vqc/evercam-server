defmodule AccessRight do
  use EvercamMedia.Web, :model
  import Ecto.Query
  import Permissions.Camera, only: [is_owner?: 2]
  alias EvercamMedia.Repo

  schema "access_rights" do
    belongs_to :access_token, AccessToken, foreign_key: :token_id
    belongs_to :camera, Camera, foreign_key: :camera_id
    belongs_to :grantor, User, foreign_key: :grantor_id
    belongs_to :snapshot, Snapshot, foreign_key: :snapshot_id
    belongs_to :account, User, foreign_key: :account_id

    field :right, :string
    field :status, :integer
    field :scope, :string

    field :updated_at, Ecto.DateTime, default: Ecto.DateTime.utc
    field :created_at, Ecto.DateTime, default: Ecto.DateTime.utc
  end

  def active_for(_camera, nil), do: []
  def active_for(camera, user) do
    token = AccessToken.active_token_for(user.id)
    AccessRight
    |> where([ar], ar.camera_id == ^camera.id)
    |> where([ar], ar.token_id == ^token.id)
    |> where([ar], ar.status == 1)
    |> Repo.all
  end

  def list(camera, user) do
    cond do
      is_owner?(user, camera) ->
        "snapshot,view,edit,delete,list,grant~snapshot,grant~view,grant~edit,grant~delete,grant~list"
      camera.access_rights == [] ->
        "snapshot,list"
      true ->
        camera.access_rights |> Enum.map(fn(ar) -> ar.right end) |> Enum.uniq |> Enum.join(",")
    end
  end
end
