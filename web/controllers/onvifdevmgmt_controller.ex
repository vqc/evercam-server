defmodule EvercamMedia.ONVIFDeviceManagementController do
  use Phoenix.Controller
  alias EvercamMedia.ONVIFDeviceManagement
  require Logger

  def get_device_information(conn, %{"id" => id}) do
    {:ok, response} = id
    |> Camera.get_camera_info 
    |> ONVIFDeviceManagement.get_device_information
    default_respond(conn, 200, response)
  end

  def get_network_interfaces(conn, %{"id" => id}) do
    {:ok, response} = id
    |> Camera.get_camera_info 
    |> ONVIFDeviceManagement.get_network_interfaces
    default_respond(conn, 200, response)
  end

   def get_capabilities(conn, %{"id" => id}) do
    {:ok, response} = id
    |> Camera.get_camera_info 
    |> ONVIFDeviceManagement.get_capabilities
    default_respond(conn, 200, response)
  end

  defp default_respond(conn, code, response) do
    conn
    |> put_status(code)
    |> put_resp_header("access-control-allow-origin", "*")
    |> json response
  end
end
