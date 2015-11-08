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
end
