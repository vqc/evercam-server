defmodule EvercamMedia.UserSignup do
  alias EvercamMedia.Repo

  def set_confirmed_at(changeset, key) do
    if key do
      changeset |> Ecto.Changeset.put_change(:confirmed_at, Ecto.DateTime.utc)
    else
      changeset
    end
  end

  def set_api_keys changeset do
    changeset
    |> Ecto.Changeset.put_change(:api_id,  UUID.uuid4(:hex))
    |> Ecto.Changeset.put_change(:api_key, UUID.uuid4(:hex))
  end

  def create(user_changeset) do
    if user_changeset.valid? do
      case Repo.insert(user_changeset) do
        { :ok, user } ->
          {:ok, exp_date } = Calendar.DateTime.now!("UTC") |> Calendar.DateTime.advance(3600)
          {:ok, expiry_date } = Calendar.DateTime.to_erl(exp_date) |> Ecto.DateTime.cast
          token = Ecto.Model.build(user, :access_tokens, is_revoked: false,
            request: UUID.uuid4(:hex), expires_at: expiry_date )

          case Repo.insert(token) do
            { :ok, token } -> { :success, user, token }
            { :error, changeset } -> { :invalid_token, changeset }
          end
          { :error, changeset } -> { :duplicate_user, changeset }
      end
    else
      { :invalid_user, user_changeset }
    end
  end
end

