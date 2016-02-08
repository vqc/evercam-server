defmodule EvercamMedia.AuthenticationPlug do
  import Plug.Conn

  def init(_opts) do
  end

  def call(conn, _) do
    api_key = extract_api_credential(conn, %{header: "x-api-key", query: "api_key"})
    api_id  = extract_api_credential(conn, %{header: "x-api-id", query: "api_id"})

    case EvercamMedia.Auth.validate(api_id, api_key) do
      :valid ->
        conn
      {:valid, user} ->
        assign(conn, :current_user, user)
      :invalid ->
        conn
        |> resp(401, Poison.encode!(%{ message: "Invalid API keys" }, []))
        |> send_resp
        |> halt
    end
  end

  defp extract_api_credential(conn, %{ header: header_name, query: query_string_name }) do
    extract_credential_from_query_string(conn, query_string_name) || extract_credential_from_header(conn, header_name)
  end

  defp extract_credential_from_query_string(conn, query_string_name) do
    Plug.Conn.fetch_query_params(conn, query_string_name)
    Map.get(conn.params, query_string_name, nil)
  end

  defp extract_credential_from_header(conn, header_name) do
    conn
    |> Plug.Conn.get_req_header(header_name)
    |> List.first
  end
end
