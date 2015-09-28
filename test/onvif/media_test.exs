defmodule MediaTest do
  use ExUnit.Case
  alias EvercamMedia.ONVIFMedia
  
  test "get_profiles method on hikvision camera" do
    {:ok, response} = ONVIFMedia.get_profiles("http://149.13.244.32:8100", "admin", "mehcam")
    [profile_1, profile_2, profile_3] = Map.get(response, "Profiles")
    assert Map.get(profile_1, "token")  == "Profile_1"
    assert Map.get(profile_2, "token") == "Profile_2"
    assert Map.get(profile_3, "token") == "Profile_3"
  end

  test "test see log when error" do
    {:error, status, _} = ONVIFMedia.get_profiles("http://149.13.244.32:8100","foo","bar")
    assert status == 400
  end 

end

