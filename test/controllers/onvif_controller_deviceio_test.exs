defmodule EvercamMedia.ONVIFControllerDeviceIOTest do
  use EvercamMedia.ConnCase

  @access_params "url=http://149.13.244.32:8100&auth=admin:mehcam"
 
  test "GET /v1/onvif/v20/DeviceIO/GetAudioOutputs" do
    conn = get conn(), "/v1/onvif/v20/DeviceIO/GetAudioOutputs?#{@access_params}"
    token = json_response(conn, 200)
    |> Map.get("AudioOutputs")
    |> Map.get("token")
    assert token == "AudioOutputToken"
  end

   test "GET /v1/onvif/v20/DeviceIO/GetAudioOutputConfiguration" do
    conn = get conn(), "/v1/onvif/v20/DeviceIO/GetAudioOutputConfiguration?#{@access_params}&AudioOutputToken=AudioOutputToken"
    send_primacy = json_response(conn, 200)
    |> Map.get("AudioOutputConfiguration")
    |> Map.get("SendPrimacy")
    assert send_primacy == "www.onvif.org/ver20/HalfDuplex/Server"
  end 
    
end
