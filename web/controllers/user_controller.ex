defmodule EvercamMedia.UserController do
  use EvercamMedia.Web, :controller
  alias EvercamMedia.UserView
  alias EvercamMedia.ErrorView

  def get(conn, params) do
    caller = conn.assigns[:current_user]
    user =
      params["id"]
      |> String.replace_trailing(".json", "")
      |> String.downcase
      |> User.by_username
    cond do
      !user ->
        conn
        |> put_status(404)
        |> render(ErrorView, "error.json", %{message: "User does not exist."})
      !caller || !Permissions.User.can_view?(caller, user) ->
        conn
        |> put_status(401)
        |> render(ErrorView, "error.json", %{message: "Unauthorized."})
      true ->
        conn
        |> render(UserView, "show.json", %{user: user})
    end
  end
end
