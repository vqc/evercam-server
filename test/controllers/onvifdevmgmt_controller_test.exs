defmodule EvercamMedia.ONVIFDeviceManagementControllerTest do
  use EvercamMedia.ConnCase

  test "GET /v1/cameras/:id/macaddr, returns MAC address" do
    conn = get conn(), "/v1/cameras/mobile-mast-test/macaddr"
    mac_address = json_response(conn, 200) |> Map.get("mac_address")
    assert mac_address == "44:19:b6:4b:f1:a2"
  end

  test "GET /v1/cameras/:id/camerainfo, returns meaningful info" do
    conn = get conn(), "/v1/cameras/mobile-mast-test/camerainfo"
    camera_model = json_response(conn, 200) |> Map.get("Model")
    assert camera_model == "DS-2DF7286-A"
  end
 
  test "GET /v1/cameras/:id/networkinterfaces, returns meaningful info" do
    conn = get conn(), "/v1/cameras/mobile-mast-test/networkinterfaces"
    enabled =  json_response(conn, 200) |> Map.get("Enabled")
    assert enabled == "true"
  end
end
