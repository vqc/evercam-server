defmodule EvercamMedia.ONVIFPTZControllerTest do
  use EvercamMedia.ConnCase
  use ExVCR.Mock, options: [clear_mock: true]

  test "GET /v1/cameras/:id/ptz/presets, gives something" do
    use_cassette "ptz_presets" do
      conn = get build_conn(), "/v1/cameras/recorded-response/ptz/presets"
      presets = conn |> json_response(200) |> Map.get("Presets")
      assert presets != nil
    end
  end

  test "GET /v1/cameras/:id/ptz/status, gives something" do
    use_cassette "ptz_status" do
      conn = get build_conn(), "/v1/cameras/recorded-response/ptz/status"
      error_status = conn |> json_response(200) |> Map.get("PTZStatus") |> Map.get("Error")
      assert error_status == "NO error"
    end
  end
end
