defmodule AccessRight do
  use EvercamMedia.Web, :model
  import Ecto.Query
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
end
