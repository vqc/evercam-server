defmodule EvercamMedia.UserController do
  use EvercamMedia.Web, :controller

  def create(conn, %{ "user" => user_params, "key" => share_key }) do
    user_changeset = User.changeset(%User{}, user_params)

    user_changeset
    |> set_user_confirmation
    |> handle_user_signup(conn)
  end

  def create(conn, %{ "user" => user_params }) do
    user_changeset = User.changeset(%User{}, user_params)

    user_changeset
    |> handle_user_signup(conn)
  end

  def update(conn, %{ "token" => token, "user" => user_params }) do
  end

  defp handle_user_signup user_changeset, conn do
    case EvercamMedia.UserSignup.create(user_changeset) do
      { :invalid_user, changeset } ->
        handle_error(conn, :bad_request, changeset)
      { :duplicate_user,  changeset } ->
        handle_error(conn, :conflict, changeset)
      { :invalid_token, changeset } ->
        handle_error(conn, :unprocessable_entity, changeset)
      { :success, user, token } ->
        conn
        |> put_status(:created)
        |> put_resp_header("access-control-allow-origin", "*")
        |> render("user.json", %{ user: user, token: token })
    end
  end

  defp set_user_confirmation(user_changeset) do
    user_changeset
    |> Ecto.Changeset.put_change(:confirmed_at, Ecto.DateTime.utc)
  end

  defp handle_error(conn, status, changeset) do
    conn
    |> put_status(status)
    |> put_resp_header("access-control-allow-origin", "*")
    |> render(EvercamMedia.ChangesetView, "error.json", changeset: changeset)
  end
end
