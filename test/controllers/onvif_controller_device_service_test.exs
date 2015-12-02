defmodule EvercamMedia.ONVIFControllerDeviceServiceTest do
  use EvercamMedia.ConnCase

  @access_params "url=http://149.13.244.32:8100&auth=admin:mehcam"
 
  test "GET /v1/onvif/v20/device_service/GetDeviceInformation, returns meaningful info" do
    conn = get conn(), "/v1/onvif/v20/device_service/GetDeviceInformation?#{@access_params}"
    camera_model = json_response(conn, 200) |> Map.get("Model")
    assert camera_model == "DS-2DF7286-A"
  end

  test "GET /v1/onvif/v20/device_service/GetNetworkInterfaces, returns meaningful info" do
    conn = get conn(), "/v1/onvif/v20/device_service/GetNetworkInterfaces?#{@access_params}"
    enabled =  json_response(conn, 200) |> Map.get("NetworkInterfaces") |> Map.get("Enabled")
    assert enabled == "true"
  end

  test "GET /v1/onvif/v20/device_service/GetCapabilities, returns meaningful info" do
    conn = get conn(), "/v1/onvif/v20/device_service/GetCapabilities?#{@access_params}"
    device_xaddr = json_response(conn, 200) |> Map.get("Capabilities") |> Map.get("Device") |> Map.get("XAddr")
    assert device_xaddr == "http://192.168.1.100:8100/onvif/device_service"
  end 
end
