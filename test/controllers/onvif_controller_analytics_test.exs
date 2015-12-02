defmodule EvercamMedia.ONVIFControllerAnalyticsTest do
  use EvercamMedia.ConnCase

  @access_params "url=http://149.13.244.32:8100&auth=admin:mehcam"

  test "GET /v1/onvif/v20/Analytics/GetServiceCapabilities" do
    conn = get conn(), "/v1/onvif/v20/Analytics/GetServiceCapabilities?#{@access_params}"
    analytics_module_support = json_response(conn, 200) |> Map.get("Capabilities") |> Map.get("AnalyticsModuleSupport")
    assert analytics_module_support == "true"
  end


  test "GET /v1/onvif/v20/Analytics/GetAnalyticsModules" do
    conn = get conn(), "/v1/onvif/v20/Analytics/GetAnalyticsModules?#{@access_params}&ConfigurationToken=VideoAnalyticsToken"
    [cell_motion_engine | _] = json_response(conn, 200) |> Map.get("AnalyticsModule")
    assert Map.get(cell_motion_engine, "Name") == "MyCellMotionModule"
  end
end
