defmodule EvercamMedia.AuthenticationPlug do
  import Plug.Conn

  def init(_opts) do
  end
  
  def call(conn, _) do
    api_key = conn
              |> Plug.Conn.get_req_header("x-api-key")
              |> List.first
    api_id = conn
             |> Plug.Conn.get_req_header("x-api-id")
             |> List.first

    case EvercamMedia.Auth.validate(api_id, api_key) do
      :valid ->
        conn
      :invalid ->
        conn
        |> resp(401, Poison.encode!(%{ error: %{ message: "Invalid API keys" }}, []))
        |> send_resp()
        |> halt()
    end
  end
end
