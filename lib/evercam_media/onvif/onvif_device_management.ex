defmodule EvercamMedia.ONVIFDeviceManagement do
  alias EvercamMedia.ONVIFClient

  def device_management_request(access_info, method) do
    xpath = "/env:Envelope/env:Body/tds:#{method}Response"
    ONVIFClient.onvif_call(access_info, :device, method, xpath)
  end
end
