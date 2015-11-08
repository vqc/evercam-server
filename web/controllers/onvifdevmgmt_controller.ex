defmodule EvercamMedia.ONVIFDeviceManagementController do
  use Phoenix.Controller
  alias EvercamMedia.ONVIFDeviceManagement
  require Logger
  
  def invoke_no_params(conn, _params) do 
    {:ok, response} = conn.assigns.onvif_access_info 
    |> ONVIFDeviceManagement.device_management_request List.last conn.path_info
    default_respond(conn, 200, response)
  end

  defp default_respond(conn, code, response) do
    conn
    |> put_status(code)
    |> put_resp_header("access-control-allow-origin", "*")
    |> json response
  end
end
