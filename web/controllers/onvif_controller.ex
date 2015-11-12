defmodule EvercamMedia.ONVIFController do
  use Phoenix.Controller
  alias EvercamMedia.ONVIFClient
  require Logger
  
  def invoke_no_params(conn, %{"service" => service, "operation" => operation}) do 
    {:ok, response} = conn.assigns.onvif_access_info 
    |> ONVIFClient.request(service, operation)
    default_respond(conn, 200, response)
  end

  def get_snapshot_uri(conn, %{"profile" => profile}) do
    {:ok, response} = conn.assigns.onvif_access_info
    |> ONVIFClient.request("media", "GetSnapshotUri", "<ProfileToken>#{profile}</ProfileToken>")
    default_respond(conn, 200, response)
  end

  defp default_respond(conn, code, response) do
    conn
    |> put_status(code)
    |> put_resp_header("access-control-allow-origin", "*")
    |> json response
  end
end
