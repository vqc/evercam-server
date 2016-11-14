defmodule EvercamMedia.ONVIFControllerDeviceServiceTest do
  use EvercamMedia.ConnCase
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]

  @auth System.get_env["ONVIF_AUTH"]

  @moduletag :onvif
  @access_params "url=http://recorded_response&auth=#{@auth}"

  @tag :skip
  test "GET /v1/onvif/v20/device_service/GetDeviceInformation, returns meaningful info" do
    use_cassette "get_device_information" do
      conn = get build_conn(), "/v1/onvif/v20/device_service/GetDeviceInformation?#{@access_params}"
      camera_model = json_response(conn, 200) |> Map.get("Model")
      assert camera_model == "DS-2DF7286-A"
    end
  end

  @tag :skip
  test "GET /v1/onvif/v20/device_service/GetNetworkInterfaces, returns meaningful info" do
    use_cassette "get_network_interfaces" do
      conn = get build_conn(), "/v1/onvif/v20/device_service/GetNetworkInterfaces?#{@access_params}"
      enabled =  json_response(conn, 200) |> Map.get("NetworkInterfaces") |> Map.get("Enabled")
      assert enabled == "true"
    end
  end

  @tag :skip
  test "GET /v1/onvif/v20/device_service/GetCapabilities, returns meaningful info" do
    use_cassette "get_capabilities" do
      conn = get build_conn(), "/v1/onvif/v20/device_service/GetCapabilities?#{@access_params}"
      device_xaddr = json_response(conn, 200) |> Map.get("Capabilities") |> Map.get("Device") |> Map.get("XAddr")
      assert device_xaddr == "http://192.168.1.100:8100/onvif/device_service"
    end
  end
end
