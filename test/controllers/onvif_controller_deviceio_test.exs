defmodule EvercamMedia.ONVIFControllerDeviceIOTest do
  use EvercamMedia.ConnCase
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]

  @auth Application.get_env(:evercam_media, :dummy_auth)

  @moduletag :onvif
  @access_params "url=http://recorded_response&auth=#{@auth}"

  test "GET /v1/onvif/v20/DeviceIO/GetAudioOutputs" do
    use_cassette "get_audio_outputs" do
      conn = get build_conn(), "/v1/onvif/v20/DeviceIO/GetAudioOutputs?#{@access_params}"
      token = json_response(conn, 200) |> Map.get("AudioOutputs") |> Map.get("token")
      assert token == "AudioOutputToken"
    end
  end

  test "GET /v1/onvif/v20/DeviceIO/GetAudioOutputConfiguration" do
    use_cassette "get_audio_output_configuration" do
      conn = get build_conn(), "/v1/onvif/v20/DeviceIO/GetAudioOutputConfiguration?#{@access_params}&AudioOutputToken=AudioOutputToken"
      send_primacy = json_response(conn, 200) |> Map.get("AudioOutputConfiguration") |> Map.get("SendPrimacy")
      assert send_primacy == "www.onvif.org/ver20/HalfDuplex/Server"
    end
  end
end
