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
      password = user.password
      with changeset = User.changeset(user, %{password: "1234567890"}),
           {:ok, user} <- Repo.update(changeset),
           changeset = User.changeset(user, %{password: password}),
           {:ok, user} <- Repo.update(changeset)
      do
        Logger.info "Password successfully updated for user '#{user.username}'"
      else
        {:error, _changeset} ->
          Logger.error "Error updating password for user '#{user.username}'"
      end
    end)
  end
end
