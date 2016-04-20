defmodule EvercamMedia.ONVIFControllerAnalyticsTest do
  use EvercamMedia.ConnCase
  use ExVCR.Mock, options: [clear_mock: true]

  @access_params "url=http://recorded_response&auth=admin:mehcam"

  test "GET /v1/onvif/v20/Analytics/GetServiceCapabilities" do
    use_cassette "get_service_capabilities" do
      conn = get conn(), "/v1/onvif/v20/Analytics/GetServiceCapabilities?#{@access_params}"
      analytics_module_support = json_response(conn, 200) |> Map.get("Capabilities") |> Map.get("AnalyticsModuleSupport")
      assert analytics_module_support == "true"
    end
  end

  test "GET /v1/onvif/v20/Analytics/GetAnalyticsModules" do
    use_cassette "get_analytics_modules" do
      conn = get conn(), "/v1/onvif/v20/Analytics/GetAnalyticsModules?#{@access_params}&ConfigurationToken=VideoAnalyticsToken"
      [cell_motion_engine | _] = json_response(conn, 200) |> Map.get("AnalyticsModule")
      assert Map.get(cell_motion_engine, "Name") == "MyCellMotionModule"
    end
  end
end
