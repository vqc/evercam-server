defmodule MediaTest do
  use ExUnit.Case
  alias EvercamMedia.ONVIFMedia
  
  test "media_request method on hikvision camera" do
    {:ok, response} = ONVIFMedia.media_request(%{url: "http://149.13.244.32:8100", auth: "admin:mehcam"}, "GetProfiles")
    [profile_1, profile_2, profile_3] = Map.get(response, "Profiles")
    assert Map.get(profile_1, "token")  == "Profile_1"
    assert Map.get(profile_2, "token") == "Profile_2"
    assert Map.get(profile_3, "token") == "Profile_3"
  end

  test "get_snapshot_uri method on hikvision camera" do
    {:ok, response} = ONVIFMedia.get_snapshot_uri(%{url: "http://149.13.244.32:8100", auth: "admin:mehcam"}, "Profile_1")
    snapshot_uri = response
    |> Map.get("MediaUri")
    |> Map.get("Uri")
    assert snapshot_uri == "http://192.168.1.100:8100/onvif/snapshot"
  end
  
end

