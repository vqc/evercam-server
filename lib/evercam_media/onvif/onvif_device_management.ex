defmodule EvercamMedia.ONVIFDeviceManagement do
  alias EvercamMedia.ONVIFClient

  def get_system_date_and_time(access_info) do
    access_info
    |> device_management_request "GetSystemDateAndTime"
  end

  def get_device_information(access_info) do
    access_info
    |> device_management_request "GetDeviceInformation"
  end

  def get_network_interfaces(access_info) do
    access_info
    |> device_management_request "GetNetworkInterfaces"
  end

  def get_capabilities(access_info) do 
    access_info
    |> device_management_request "GetCapabilities"
  end

  defp device_management_request(access_info, method) do
    xpath = "/env:Envelope/env:Body/tds:#{method}Response"
    ONVIFClient.onvif_call(access_info, :device, method, xpath)
  end
end
