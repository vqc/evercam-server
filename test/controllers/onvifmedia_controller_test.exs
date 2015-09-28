defmodule EvercamMedia.ONVIFMediaControllerTest do
  use EvercamMedia.ConnCase

  test "GET /v1/cameras/:id/profiles, returns profile information" do
    conn = get conn(), "/v1/cameras/mobile-mast-test/profiles"
    [profile_1, _, _] = json_response(conn, 200) |> Map.get("Profiles")
    assert Map.get(profile_1, "token")  == "Profile_1"
  end
end
