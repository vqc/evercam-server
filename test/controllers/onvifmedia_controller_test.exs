defmodule EvercamMedia.ONVIFMediaControllerTest do
  use EvercamMedia.ConnCase

  test "GET /v1/devices/:id/onvif/v20/GetProfiles, returns profile information" do
    conn = get conn(), "/v1/devices/mobile-mast-test/onvif/v20/GetProfiles"
    [profile_1, _, _] = json_response(conn, 200) |> Map.get("Profiles")
    assert Map.get(profile_1, "token")  == "Profile_1"
  end

  test "GET /v1/devices/:id/onvif/v20/GetServiceCapabilities, returns profile information" do
    conn = get conn(), "/v1/devices/mobile-mast-test/onvif/v20/GetServiceCapabilities"
    snapshot_uri = json_response(conn, 200)
    |> Map.get("Capabilities")
    |> Map.get("SnapshotUri")
    assert snapshot_uri == "true"
  end

   test "GET /v1/devices/:id/onvif/v20/GetSnapshotUri/:profile, returns snapshot uri" do
    conn = get conn(), "/v1/devices/mobile-mast-test/onvif/v20/GetSnapshotUri/Profile_1"
    snapshot_uri = json_response(conn, 200)
    |> Map.get("MediaUri")
    |> Map.get("Uri")
    assert snapshot_uri == "http://192.168.1.100:8100/onvif/snapshot"
  end
end
