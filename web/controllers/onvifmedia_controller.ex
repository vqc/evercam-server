defmodule EvercamMedia.ONVIFMediaController do
  use Phoenix.Controller
  alias EvercamMedia.ONVIFMedia
  require Logger
  plug :action

  def profiles(conn, %{"id" => id}) do
    [url, username, password] = Camera.get_camera_info id
    {:ok, response} = ONVIFMedia.get_profiles(url, username, password)
    default_respond(conn, 200, response)
  end

  defp default_respond(conn, code, response) do
    conn
    |> put_status(code)
    |> put_resp_header("access-control-allow-origin", "*")
    |> json response
  end
end
