defmodule EvercamMedia.ONVIFControllerErrorsTest do
  use EvercamMedia.ConnCase
  use ExVCR.Mock, options: [clear_mock: true]

  @access_params "url=http://recorded_response&auth=admin:mehcam"

  @tag :capture_log
  test "GET /v1/onvif/v20/DeviceIO/GetUnknownAction" do
    use_cassette "error_unknown_action" do
      conn = get conn(), "/v1/onvif/v20/DeviceIO/GetUnknownAction?#{@access_params}"
      error_type = json_response(conn, 500) |> parse_error_type
      assert error_type == "ter:ActionNotSupported"
    end
  end

  @tag :capture_log
  test "bad credentials" do
    use_cassette "error_bad_credentials" do
      conn = get conn(), "/v1/onvif/v20/device_service/GetNetworkInterfaces?url=http://recorded_response&auth=admin:foo"
      error_type = json_response(conn, 400) |> parse_error_type
      assert error_type == "ter:NotAuthorized"
    end
  end

  @tag :capture_log
  test "Service not available" do
    use_cassette "error_service_not_available" do
      conn = get conn(), "/v1/onvif/v20/Display/GetServiceCapabilities?#{@access_params}"
      error_type = json_response(conn, 500) |> parse_error_type
      assert error_type == "ter:ActionNotSupported"
    end
  end

  @tag :capture_log
  test "bad parameter" do
    use_cassette "error_bad_parameter" do
      conn = get conn(), "/v1/onvif/v20/Media/GetSnapshotUri?#{@access_params}&ProfileToken=Foo"
      error_type = json_response(conn, 500) |> parse_error_type
      assert error_type == "ter:InvalidArgVal"
    end
  end

  @tag :capture_log
  test "request timeout" do
    use_cassette "error_request_timeout" do
      conn = get conn(), "/v1/onvif/v20/device_service/GetNetworkInterfaces?url=http://192.10.20.30:8100&auth=foo:bar"
      error_message = json_response(conn, 500) |> Map.get("message")
      assert error_message == "req_timedout"
    end
  end

  @tag :capture_log
  test "bad url" do
    use_cassette "error_bad_url" do
      conn = get conn(), "/v1/onvif/v20/device_service/GetNetworkInterfaces?url=abcde&auth=foo:bar"
      error_message = json_response(conn, 500) |> Map.get("message")
      assert error_message == "nxdomain"
    end
  end

  defp parse_error_type(response) do
    response
    |> Map.get("Fault")
    |> Map.get("Code")
    |> Map.get("Subcode")
    |> Map.get("Value")
  end
end
