defmodule EvercamMedia.Intercom do
  alias EvercamMedia.Util
  require Logger

  @intercom_url System.get_env["INTERCOM_URL"]
  @intercom_auth {System.get_env["INTERCOM_ID"], System.get_env["INTERCOM_KEY"]}
  @hackney [basic_auth: @intercom_auth]

  def get_user(user_id) do
    url = "#{@intercom_url}?user_id=#{user_id}"
    headers = ["Accept": "Accept:application/json"]
    response = HTTPoison.get(url, headers, hackney: @hackney) |> elem(1)
    case response.status_code do
      200 -> {:ok, response}
      _ -> {:error, response}
    end
  end

  def create_user(user, user_agent, requester_ip, status) do
    headers = ["Accept": "Accept:application/json", "Content-Type": "application/json"]
    intercom_new_user = %{
      "email": user.email,
      "name": user.firstname <> " " <> user.lastname,
      "last_seen_user_agent": user_agent,
      "last_request_at": user.created_at |> Util.ecto_datetime_to_unix,
      "last_seen_ip": requester_ip,
      "signed_up_at": user.created_at |> Util.ecto_datetime_to_unix,
      "custom_attributes": %{
        "viewed_camera": 0,
        "viewed_recordings": 0,
        "has_shared": false,
        "has_snapmail": false
      }
    }
    |> add_userid(user.username)
    |> add_status(status)
    json =
      case Poison.encode(intercom_new_user) do
        {:ok, json} -> json
        _ -> nil
      end
    HTTPoison.post(@intercom_url, json, headers, hackney: @hackney)
    Logger.debug "Intercom user has been created"
  end

  defp add_userid(params, ""), do: params
  defp add_userid(params, id) do
    Map.put(params, "user_id", id)
  end

  defp add_status(params, ""), do: params
  defp add_status(params, status) do
    put_in(params, [:custom_attributes, "status"], status)
  end

  def delete_user(user, by_val \\ "user_id", tries \\ 1)
  def delete_user(_user, _by_val, 3), do: :noop
  def delete_user(user, by_val, tries) do
    url = "#{@intercom_url}?#{by_val}=#{user}"
    headers = ["Accept": "Accept:application/json"]

    case HTTPoison.delete(url, headers, hackney: @hackney) do
      {:ok, _response} -> :noop
      {:error, _reason} -> delete_user(user, by_val, tries + 1)
    end
  end

  def intercom_activity(is_create, user, user_agent, requester_ip, status \\ "")
  def intercom_activity(false, _user, _user_agent, _requester_ip, _status), do: :noop
  def intercom_activity(true, user, user_agent, requester_ip, status) do
    Task.start(fn ->
      case get_user(user.username) do
        {:ok, _} -> Logger.info "User '#{user.username}' already present at Intercom."
        {:error, _} -> create_user(user, user_agent, requester_ip, status)
      end
    end)
  end

  def update_user(false, _user, _user_agent, _requester_ip), do: :noop
  def update_user(true, user, user_agent, requester_ip) do
    Task.start(fn ->
      create_user(user, user_agent, requester_ip, "Share-Accepted")
    end)
  end

  def delete_or_update_user(false, _email, _user_agent, _ip, _key), do: :noop
  def delete_or_update_user(true, email, _user_agent, _ip, nil) do
    Task.start(fn ->
      delete_user(email, "email")
    end)
  end
  def delete_or_update_user(true, email, user_agent, ip, _key) do
    Task.start(fn ->
      user = %User{
        username: "",
        firstname: "",
        lastname: "",
        email: email,
        created_at: Ecto.DateTime.utc
      }
      create_user(user, user_agent, ip, "Share-Revoked")
    end)
  end
end
