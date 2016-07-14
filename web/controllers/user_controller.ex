defmodule EvercamMedia.UserController do
  use EvercamMedia.Web, :controller
  use Calendar
  alias EvercamMedia.UserView
  alias EvercamMedia.ErrorView
  alias EvercamMedia.Repo
  alias EvercamMedia.Util
  alias EvercamMedia.Intercom
  require Logger

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
      !caller || !Permission.User.can_view?(caller, user) ->
        conn
        |> put_status(401)
        |> render(ErrorView, "error.json", %{message: "Unauthorized."})
      true ->
        conn
        |> render(UserView, "show.json", %{user: user})
    end
  end

  def credentials(conn, %{"id" => username} = params) do
    user =
      params["id"]
      |> String.replace_trailing(".json", "")
      |> String.downcase
      |> User.by_username

    with :ok <- ensure_user_exists(user, username, conn),
         :ok <- password(params["password"], user, conn)
    do
      conn
      |> render(UserView, "credentials.json", %{user: user})
    end
  end

  def create(conn, params) do
    with :ok <- ensure_country(params["country"], conn)
    do
      [user_agent|rest] = get_req_header(conn, "user-agent")
      requester_ip = parse_requester_ip(conn.remote_ip)
      user_agent = parse_user_agent(user_agent)
      share_request_key = params["share_request_key"]
      api_id = UUID.uuid4(:hex) |> String.slice(0..7)
      api_key = UUID.uuid4(:hex)
      password = create_password(params["password"])

      params =
        case Country.get_by_code(params["country"]) do
          {:ok, country} -> Map.merge(params, %{"country_id" => country.id}) |> Map.delete("country")
          {:error, nil} -> Map.delete(params, "country")
        end

      params = Map.merge(params, %{"password" => password, "api_id" => api_id, "api_key" => api_key})

      params =
        case has_share_request_key?(share_request_key) do
          true -> Map.merge(params, %{"confirmed_at" => DateTime.now_utc |> DateTime.to_erl}) |> Map.delete("share_request_key")
          false -> Map.delete(params, "share_request_key")
        end

      changeset = User.changeset(%User{}, params)
      case Repo.insert(changeset) do
        {:ok, user} ->
          {:ok, exp_date} = DateTime.now!("UTC") |> DateTime.advance(3600)
          {:ok, expiry_date} = DateTime.to_erl(exp_date) |> Ecto.DateTime.cast
          token = Ecto.build_assoc(user, :access_tokens, is_revoked: false,
            request: UUID.uuid4(:hex) |> String.slice(0..15), expires_at: expiry_date)

          case Repo.insert(token) do
            {:ok, token} -> {:success, user, token}
            {:error, changeset} -> {:invalid_token, changeset}
          end
          if !has_share_request_key?(share_request_key) do
            created_at =
              user.created_at
              |> Ecto.DateTime.to_erl
              |> Strftime.strftime!("%Y-%m-%d %T UTC")

            code =
              :crypto.hash(:sha, user.username <> created_at)
              |> Base.encode16
              |> String.downcase

            share_default_camera(user)
            EvercamMedia.UserMailer.confirm(user, code)
          else
            share_request = CameraShareRequest.by_key_and_status(share_request_key)
            create_share_for_request(share_request, user, conn)

            share_requests = CameraShareRequest.by_email(user.email)
            multiple_share_create(share_requests, user, conn)
          end

          if user |> Intercom.get_user |> intercom_user? do
            render_error(conn, 400, "User already present at intercom.")
          else
            Task.start(fn -> Intercom.create_user(user, user_agent, requester_ip) end)
            conn
            |> put_status(200)
            |> render(UserView, "show.json", %{user: user |> Repo.preload(:country, force: true)})
          end
        {:error, changeset} ->
          render_error(conn, 404, Util.parse_changeset(changeset))
      end
    end
  end

  def update(conn, %{"id" => username} = params) do
    current_user = conn.assigns[:current_user]
    user =
      params["id"]
      |> String.replace_trailing(".json", "")
      |> String.downcase
      |> User.by_username

    with :ok <- ensure_user_exists(user, username, conn),
         :ok <- ensure_can_view(current_user, user, conn),
         :ok <- ensure_country(params["country"], conn)
    do
      user_params = %{
        firstname: firstname(params["firstname"], user),
        lastname: lastname(params["lastname"], user),
        email: email(params["email"], user)
      }
      user_params = case country(params["country"], user) do
        nil -> Map.delete(user_params, "country")
        country_id -> Map.merge(user_params, %{country_id: country_id}) |> Map.delete("country")
      end
      changeset = User.changeset(user, user_params)
      case Repo.update(changeset) do
        {:ok, user} ->
          updated_user = user |> Repo.preload(:country, force: true)
          conn |> render(UserView, "show.json", %{user: updated_user})
        {:error, changeset} ->
          render_error(conn, 404, Util.parse_changeset(changeset))
      end
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
      |> json(%{message: "User has been deleted!"})
    end
  end

  defp delete_user(user) do
    # TODO: invalidate all users with whom this user has shared a camera
    User.invalidate_auth(user.api_id, user.api_key)
    Camera.invalidate_user(user)
    Camera.delete_by_owner(user.id)
    CameraShare.delete_by_user(user.id)
    User.delete_by_id(user.id)
  end

  defp firstname(firstname, user) when firstname in [nil, ""], do: user.firstname
  defp firstname(firstname, _user),  do: firstname

  defp lastname(lastname, user) when lastname in [nil, ""], do: user.lastname
  defp lastname(lastname, _user), do: lastname

  defp email(email, user) when email in [nil, ""], do: user.email
  defp email(email, _user), do: email

  defp country(country_id, user) when country_id in [nil, ""] do
    case user.country do
      nil -> nil
      country -> country.id
    end
  end
  defp country(country_id, _user) do
    country = Country.by_iso3166(country_id)
    country.id
  end

  defp ensure_user_exists(nil, username, conn) do
    render_error(conn, 404, "User '#{username}' does not exist.")
  end
  defp ensure_user_exists(_user, _id, _conn), do: :ok

  defp ensure_can_view(current_user, user, conn) do
    if current_user && Permission.User.can_view?(current_user, user) do
      :ok
    else
      render_error(conn, 403, "Unauthorized.")
    end
  end

  defp password(password, user, conn) do
    if Comeonin.Bcrypt.checkpw(password, user.password) do
      :ok
    else
      render_error(conn, 404, "Invalid password.")
    end
  end

  defp ensure_country(country_id, _conn) when country_id in [nil, ""], do: :ok
  defp ensure_country(country_id, conn) do
    country = Country.by_iso3166(country_id)
    case country do
      nil -> render_error(conn, 404, "Country isn't valid!")
      _ -> :ok
    end
  end

  defp parse_requester_ip(nil), do: "0.0.0.0"
  defp parse_requester_ip(remote_ip), do: remote_ip |> Tuple.to_list |> Enum.join(".")

  defp parse_user_agent(nil), do: "chrome"
  defp parse_user_agent(user_agent), do: user_agent

  defp has_share_request_key?(value) when value in [nil, ""], do: false
  defp has_share_request_key?(_value), do: true

  defp intercom_user?({:ok, _}), do: true
  defp intercom_user?({:error, _}), do: false

  defp share_default_camera(user) do
    evercam_user = User.by_username("evercam")
    remembrance_camera = Camera.get_remembrance_camera
    rights = CameraShare.get_rights("public", evercam_user, remembrance_camera)
    message = "Default camera shared with newly created user."

    CameraShare.create_share(remembrance_camera, user, evercam_user, rights, message, "public")
  end

  defp create_password(password) when password in [nil, ""], do: nil
  defp create_password(password), do: Comeonin.Bcrypt.hashpass(password, Comeonin.Bcrypt.gen_salt(12, true))

  defp create_share_for_request(nil, _user, conn), do: render_error(conn, 400, "Camera share request does not exist.")
  defp create_share_for_request(share_request, user, conn) do
    if share_request.email != user.email do
      render_error(conn, 400, "The email address specified does not match the share request email.")
    else
      param = %{
        status: 1
      }
      changeset = CameraShareRequest.changeset(share_request, param)

      case Repo.update(changeset) do
        {:ok, share_request} ->
          CameraShare.create_share(share_request.user, user, share_request.camera, share_request.rights, share_request.message)
        {:error, changeset} ->
          render_error(conn, 400, Util.parse_changeset(changeset))
      end
    end
  end

  defp multiple_share_create(nil, _user, _conn), do: Logger.info "No share request found."
  defp multiple_share_create(share_requests, user, conn) do
    Enum.each(share_requests, fn(share_request) -> create_share_for_request(share_request, user, conn) end)
  end
end
