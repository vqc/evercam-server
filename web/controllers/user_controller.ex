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
        render_error(conn, 404, "User does not exist.")
      !caller || !Permissions.User.can_view?(caller, user) ->
        render_error(conn, 401, "Unauthorized.")
      true ->
        conn
        |> render(UserView, "show.json", %{user: user})
    end
  end

  def delete(conn, %{"id" => username}) do
    current_user = conn.assigns[:current_user]
    user =
      username
      |> String.replace_trailing(".json", "")
      |> String.downcase
      |> User.by_username

    with :ok <- ensure_user_exists(user, username, conn),
         :ok <- ensure_can_view(current_user, user, conn)
    do
      spawn(fn -> delete_user(user) end)
      conn
      |> put_status(200)
      |> json(%{message: "User has been deleted!"})
    end
  end

  defp ensure_user_exists(nil, username, conn) do
    render_error(conn, 404, "User '#{username}' does not exist.")
  end
  defp ensure_user_exists(_user, _id, _conn), do: :ok

  defp ensure_can_view(current_user, user, conn) do
    if current_user && Permissions.User.can_view?(current_user, user) do
      :ok
    else
      render_error(conn, 401, "Unauthorized.")
    end
  end

  defp delete_user(user) do
    Camera.delete_by_owner(user.id)
    CameraShare.delete_by_user(user.id)
    User.delete_by_id(user.id)
  end
end
