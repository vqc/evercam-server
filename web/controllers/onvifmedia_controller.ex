defmodule EvercamMedia.ONVIFMediaController do
  use Phoenix.Controller
  alias EvercamMedia.ONVIFMedia
  require Logger

  def invoke_no_params(conn, _params) do 
    {:ok, response} = conn.assigns.onvif_access_info 
    |> ONVIFMedia.media_request List.last conn.path_info
    default_respond(conn, 200, response)
  end

  def get_snapshot_uri(conn, %{"profile" => profile}) do
    {:ok, response} = conn.assigns.onvif_access_info
    |> ONVIFMedia.get_snapshot_uri profile
    default_respond(conn, 200, response)
  end

  defp default_respond(conn, code, response) do
    conn
    |> put_status(code)
    |> put_resp_header("access-control-allow-origin", "*")
    |> json response
  end
end
