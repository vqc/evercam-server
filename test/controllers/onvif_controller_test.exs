defmodule EvercamMedia.ONVIFControllerTest do
  use EvercamMedia.ConnCase
 
  test "GET /v1/devices/:id/onvif/v20/device_service/GetDeviceInformation, returns meaningful info" do
    conn = get conn(), "/v1/devices/mobile-mast-test/onvif/v20/device_service/GetDeviceInformation"
    camera_model = json_response(conn, 200) |> Map.get("Model")
    assert camera_model == "DS-2DF7286-A"
  end

  test "GET /v1/devices/:id/onvif/v20/device_service/GetNetworkInterfaces, returns meaningful info" do
    conn = get conn(), "/v1/devices/mobile-mast-test/onvif/v20/device_service/GetNetworkInterfaces"
    enabled =  json_response(conn, 200)
    |> Map.get("NetworkInterfaces") 
    |> Map.get("Enabled")
    assert enabled == "true"
  end

  test "GET /v1/devices/:id/onvif/v20/device_service/GetCapabilities, returns meaningful info" do
    conn = get conn(), "/v1/devices/mobile-mast-test/onvif/v20/device_service/GetCapabilities"
    device_xaddr = json_response(conn, 200)
    |> Map.get("Capabilities")
    |> Map.get("Device")
    |> Map.get("XAddr")
    assert device_xaddr == "http://192.168.1.100:8100/onvif/device_service"
  end 


  test "GET /v1/devices/:id/onvif/v20/media/GetProfiles, returns profile information" do
    conn = get conn(), "/v1/devices/mobile-mast-test/onvif/v20/media/GetProfiles"
    [profile_1, _, _] = json_response(conn, 200) |> Map.get("Profiles")
    assert Map.get(profile_1, "token")  == "Profile_1"
  end

  test "GET /v1/devices/:id/onvif/v20/media/GetServiceCapabilities, returns profile information" do
    conn = get conn(), "/v1/devices/mobile-mast-test/onvif/v20/media/GetServiceCapabilities"
    snapshot_uri = json_response(conn, 200)
    |> Map.get("Capabilities")
    |> Map.get("SnapshotUri")
    assert snapshot_uri == "true"
  end

   test "GET /v1/devices/:id/onvif/v20/media/GetSnapshotUri/:profile, returns snapshot uri" do
    conn = get conn(), "/v1/devices/mobile-mast-test/onvif/v20/media/GetSnapshotUri/Profile_1"
    snapshot_uri = json_response(conn, 200)
    |> Map.get("MediaUri")
    |> Map.get("Uri")
    assert snapshot_uri == "http://192.168.1.100:8100/onvif/snapshot"
  end
    
end
