defmodule EvercamMedia.ONVIFControllerMediaTest do
  use EvercamMedia.ConnCase
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]

  @auth System.get_env["ONVIF_AUTH"]

  @moduletag :onvif
  @access_params "url=http://recorded_response&auth=#{@auth}"

  @tag :skip
  test "GET /v1/onvif/v20/Media/GetProfiles, returns profile information" do
    use_cassette "get_profiles" do
      conn = get build_conn(), "/v1/onvif/v20/Media/GetProfiles?#{@access_params}"
      [profile_1, _, _] = json_response(conn, 200) |> Map.get("Profiles")
      assert Map.get(profile_1, "token")  == "Profile_1"
    end
  end

  @tag :skip
  test "GET /v1/onvif/v20/Media/GetServiceCapabilities, returns profile information" do
    use_cassette "media_get_service_capabilities" do
      conn = get build_conn(), "/v1/onvif/v20/Media/GetServiceCapabilities?#{@access_params}"
      snapshot_uri = json_response(conn, 200) |> Map.get("Capabilities") |> Map.get("SnapshotUri")
      assert snapshot_uri == "true"
    end
  end

  @tag :skip
  test "GET /v1/onvif/v20/Media/GetSnapshotUri, returns snapshot uri" do
    use_cassette "get_snapshot_uri" do
      conn = get build_conn(), "/v1/onvif/v20/Media/GetSnapshotUri?#{@access_params}&ProfileToken=Profile_1"
      snapshot_uri = json_response(conn, 200) |> Map.get("MediaUri") |> Map.get("Uri")
      assert snapshot_uri == "http://192.168.1.100:8100/onvif-http/snapshot?Profile_1"
    end
  end

  @tag :skip
  test "GET /v1/onvif/v20/Media/GetVideoAnalyticsConfigurations" do
    use_cassette "get_video_analytics_configuration" do
      conn = get build_conn(), "/v1/onvif/v20/Media/GetVideoAnalyticsConfigurations?#{@access_params}"
      token = json_response(conn, 200) |> Map.get("Configurations") |> Map.get("token")
      assert token == "VideoAnalyticsToken"
    end
  end

  @tag :skip
  test "GET /v1/onvif/v20/Media/GetVideoSources" do
    use_cassette "get_video_sources" do
      conn = get build_conn(), "/v1/onvif/v20/Media/GetVideoSources?#{@access_params}"
      video_source = json_response(conn, 200) |> Map.get("VideoSources") |> Map.get("token")
      assert video_source == "VideoSource_1"
    end
  end

  @tag :skip
  test "GET /v1/onvif/v20/Media/GetSnapshotUri using camera_id" do
    use_cassette "get_snapshot_uri_from_db" do
      conn = get build_conn(), "/v1/onvif/v20/Media/GetSnapshotUri?id=recorded-response&ProfileToken=Profile_1"
      snapshot_uri = json_response(conn, 200) |> Map.get("MediaUri") |> Map.get("Uri")
      assert snapshot_uri == "http://192.168.1.100:8100/onvif-http/snapshot?Profile_1"
    end
  end
end
