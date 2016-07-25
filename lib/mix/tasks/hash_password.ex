defmodule EvercamMedia.HashPassword do
  alias EvercamMedia.Repo
  import Ecto.Query
  require Logger

  def run do
    {:ok, _} = Application.ensure_all_started(:evercam_media)

    User
    |> where([user], fragment("LENGTH(?) < 50", user.password))
    |> Repo.all
    |> Enum.each(fn(user) ->
      changeset = User.changeset(user, %{password: user.password})

      case Repo.update(changeset) do
        {:ok, user} ->
          Logger.info "Password successfully updated for user '#{user.username}'"
        {:error, _changeset} ->
          Logger.error "Error updating password for user '#{user.username}'"
      end
    end)
  end
end
