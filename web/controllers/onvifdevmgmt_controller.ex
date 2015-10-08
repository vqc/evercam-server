defmodule EvercamMedia.ONVIFDeviceManagementController do
  use Phoenix.Controller
  alias EvercamMedia.ONVIFDeviceManagement
  require Logger

  def macaddr(conn, %{"id" => id}) do
    [url, username, password] = Camera.get_camera_info id
    {:ok, response} = ONVIFDeviceManagement.get_network_interfaces(url, username, password)
    mac_address = response
    |> Map.get("Info")
    |> Map.get("HwAddress")
    macaddr_respond(conn, 200, mac_address)
  end

  def camerainfo(conn, %{"id" => id}) do
    [url, username, password] = Camera.get_camera_info id
    {:ok, response} = ONVIFDeviceManagement.get_device_information(url, username, password)
    default_respond(conn, 200, response)
  end

  def networkinterfaces(conn, %{"id" => id}) do
    [url, username, password] = Camera.get_camera_info id
    {:ok, response} = ONVIFDeviceManagement.get_network_interfaces(url, username, password)
    default_respond(conn, 200, response)
  end

  defp macaddr_respond(conn, code, mac_address) do
    conn
    |> put_status(code)
    |> put_resp_header("access-control-allow-origin", "*")
    |> json %{mac_address: mac_address}
  end

  defp default_respond(conn, code, response) do
    conn
    |> put_status(code)
    |> put_resp_header("access-control-allow-origin", "*")
    |> json response
  end
end
