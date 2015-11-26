defmodule EvercamMedia.ONVIFControllerMediaTest do
  use EvercamMedia.ConnCase

  @access_params "url=http://149.13.244.32:8100&auth=admin:mehcam"
 

  test "GET /v1/onvif/v20/Media/GetProfiles, returns profile information" do
    conn = get conn(), "/v1/onvif/v20/Media/GetProfiles?#{@access_params}"
    [profile_1, _, _] = json_response(conn, 200) |> Map.get("Profiles")
    assert Map.get(profile_1, "token")  == "Profile_1"
  end

  test "GET /v1/onvif/v20/Media/GetServiceCapabilities, returns profile information" do
    conn = get conn(), "/v1/onvif/v20/Media/GetServiceCapabilities?#{@access_params}"
    snapshot_uri = json_response(conn, 200)
    |> Map.get("Capabilities")
    |> Map.get("SnapshotUri")
    assert snapshot_uri == "true"
  end

  test "GET /v1/onvif/v20/Media/GetSnapshotUri, returns snapshot uri" do
    conn = get conn(), "/v1/onvif/v20/Media/GetSnapshotUri?#{@access_params}&ProfileToken=Profile_1"
    snapshot_uri = json_response(conn, 200)
    |> Map.get("MediaUri")
    |> Map.get("Uri")
    assert snapshot_uri == "http://192.168.1.100:8100/onvif/snapshot"
  end

  test "GET /v1/onvif/v20/Media/GetVideoAnalyticsConfigurations" do
    conn = get conn(), "/v1/onvif/v20/Media/GetVideoAnalyticsConfigurations?#{@access_params}"
    token = json_response(conn, 200) 
    |> Map.get("Configurations")
    |> Map.get("token")
    assert token == "VideoAnalyticsToken"
  end

  test "GET /v1/onvif/v20/Media/GetVideoSources" do
    conn = get conn(), "/v1/onvif/v20/Media/GetVideoSources?#{@access_params}"
    video_source = json_response(conn, 200)
    |> Map.get("VideoSources")
    |> Map.get("token")
    assert video_source == "VideoSource_1" 
  end

  test "GET /v1/onvif/v20/Media/GetSnapshotUri using camera_id" do
    conn = get conn(), "/v1/onvif/v20/Media/GetSnapshotUri?id=mobile-mast-test&ProfileToken=Profile_1"
    snapshot_uri = json_response(conn, 200)
    |> Map.get("MediaUri")
    |> Map.get("Uri")
    assert snapshot_uri == "http://192.168.1.100:8100/onvif/snapshot"
  end
    
end
