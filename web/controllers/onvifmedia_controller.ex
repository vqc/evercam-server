defmodule EvercamMedia.ONVIFMediaController do
  use Phoenix.Controller
  alias EvercamMedia.ONVIFMedia
  require Logger

  def get_profiles(conn, %{"id" => id}) do
    {:ok, response} = id
    |> Camera.get_camera_info
    |> ONVIFMedia.get_profiles
    default_respond(conn, 200, response)
  end

  def get_service_capabilities(conn, %{"id" => id}) do
    {:ok, response} = id
    |> Camera.get_camera_info 
    |> ONVIFMedia.get_service_capabilities
    default_respond(conn, 200, response)
  end

  def get_snapshot_uri(conn, %{"id" => id, "profile" => profile}) do
    {:ok, response} = id
    |> Camera.get_camera_info 
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
