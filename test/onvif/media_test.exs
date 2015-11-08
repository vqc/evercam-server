defmodule MediaTest do
  use ExUnit.Case
  alias EvercamMedia.ONVIFMedia
  
  test "get_profiles method on hikvision camera" do
    {:ok, response} = ONVIFMedia.get_profiles(%{url: "http://149.13.244.32:8100", auth: "admin:mehcam"})
    [profile_1, profile_2, profile_3] = Map.get(response, "Profiles")
    assert Map.get(profile_1, "token")  == "Profile_1"
    assert Map.get(profile_2, "token") == "Profile_2"
    assert Map.get(profile_3, "token") == "Profile_3"
  end

  test "get_service_capabilities method on hikvision camera" do
    {:ok, response} = ONVIFMedia.get_service_capabilities(%{url: "http://149.13.244.32:8100", auth: "admin:mehcam"})
    snapshot_uri = response
    |> Map.get("Capabilities")
    |> Map.get("SnapshotUri")
    assert snapshot_uri == "true"
  end
  
  test "test see log when error" do
    {:error, status, _} = ONVIFMedia.get_profiles(%{url: "http://149.13.244.32:8100", auth: "foo:bar"})
    assert status == 400
  end 

end

