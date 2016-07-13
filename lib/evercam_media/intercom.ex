defmodule EvercamMedia.Intercom do
  alias EvercamMedia.Util
  require Logger

  @intercom_url System.get_env["INTERCOM_URL"]
  @intercom_auth {System.get_env["INTERCOM_ID"], System.get_env["INTERCOM_KEY"]}

  def get_user(user) do
    url = "#{@intercom_url}?user_id=#{user.username}"
    headers = ["Accept": "Accept:application/json"]
    intercom_user = HTTPotion.get(url, [basic_auth: @intercom_auth, headers: headers])
    case HTTPotion.Response.success?(intercom_user) do
      true -> {:ok, intercom_user}
      false -> {:error, intercom_user}
    end
  end

  def create_user(user, user_agent, requester_ip) do
    headers = ["Accept": "Accept:application/json", "Content-Type": "application/json"]
    intercom_new_user = %{
      "email": user.email,
      "user_id": user.username,
      "name": user.firstname <> " " <> user.lastname,
      "last_seen_user_agent": user_agent,
      "last_request_at": user.created_at |> Util.ecto_datetime_to_unix,
      "last_seen_ip": requester_ip,
      "signed_up_at": user.created_at |> Util.ecto_datetime_to_unix
    }
    json =
      case Poison.encode(intercom_new_user) do
        {:ok, json} -> json
        _ -> nil
      end
    HTTPotion.post(@intercom_url, [body: json, basic_auth: @intercom_auth, headers: headers, timeout: 4000])
    Logger.info "Intercom user has been created"
  end
end
