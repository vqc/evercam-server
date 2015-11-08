defmodule EvercamMedia.ONVIFDeviceManagementControllerTest do
  use EvercamMedia.ConnCase

 
  test "GET /v1/devices/:id/onvif/v20/GetDeviceInformation, returns meaningful info" do
    conn = get conn(), "/v1/devices/mobile-mast-test/onvif/v20/GetDeviceInformation"
    camera_model = json_response(conn, 200) |> Map.get("Model")
    assert camera_model == "DS-2DF7286-A"
  end

  test "GET /v1/devices/:id/onvif/v20/GetNetworkInterfaces, returns meaningful info" do
    conn = get conn(), "/v1/devices/mobile-mast-test/onvif/v20/GetNetworkInterfaces"
    enabled =  json_response(conn, 200)
    |> Map.get("NetworkInterfaces") 
    |> Map.get("Enabled")
    assert enabled == "true"
  end

  test "GET /v1/devices/:id/onvif/v20/GetCapabilities, returns meaningful info" do
    conn = get conn(), "/v1/devices/mobile-mast-test/onvif/v20/GetCapabilities"
    device_xaddr = json_response(conn, 200)
    |> Map.get("Capabilities")
    |> Map.get("Device")
    |> Map.get("XAddr")
    assert device_xaddr == "http://192.168.1.100:8100/onvif/device_service"
  end 
    
end
