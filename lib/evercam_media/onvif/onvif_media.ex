defmodule EvercamMedia.ONVIFMedia do
  alias EvercamMedia.ONVIFClient

  def get_profiles(access_info) do
    access_info 
    |> media_request "GetProfiles"
  end

  def get_service_capabilities(access_info) do
    access_info
    |> media_request "GetServiceCapabilities"
  end

  def get_snapshot_uri(access_info, profile_token) do
    parameters = "<ProfileToken>#{profile_token}</ProfileToken>"
    access_info
    |> media_request("GetSnapshotUri", parameters)
  end

  defp media_request(access_info, method, parameters \\ "") do
    xpath = "/env:Envelope/env:Body/trt:#{method}Response"
    ONVIFClient.onvif_call(access_info, :media, method, xpath, parameters)
  end

end
