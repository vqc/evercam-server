defmodule EvercamMedia.ONVIFControllerErrorsTest do
  use EvercamMedia.ConnCase

  @access_params "url=http://149.13.244.32:8100&auth=admin:mehcam"
 
  test "GET /v1/onvif/v20/DeviceIO/GetUnknownActiopn" do
    conn = get conn(), "/v1/onvif/v20/DeviceIO/GetUnknownAction?#{@access_params}"
    error_message = json_response(conn, 500)
    |> Map.get("Fault")
    |> Map.get("Code")
    |> Map.get("Subcode")
    |> Map.get("Value")
    assert error_message == "ter:ActionNotSupported"
  end
  
  test "bad credentials" do
    conn = get conn(), "/v1/onvif/v20/device_service/GetNetworkInterfaces?url=http://149.13.244.32:8100&auth=admin:foo"
    error_value = json_response(conn, 400)
    |> Map.get("Fault")
    |> Map.get("Code")
    |> Map.get("Subcode")
    |> Map.get("Value")
    assert error_value == "ter:NotAuthorized"
  end

   test "Service not available" do
    conn = get conn(), "/v1/onvif/v20/Display/GetServiceCapabilities?#{@access_params}"
    error_message = json_response(conn, 500)
    |> Map.get("Fault")
    |> Map.get("Code")
    |> Map.get("Subcode")
    |> Map.get("Value")
    assert error_message == "ter:ActionNotSupported"
  end

  test "bad parameter" do
    conn = get conn(), "/v1/onvif/v20/Media/GetSnapshotUri?#{@access_params}&ProfileToken=Foo"
    error_message = json_response(conn, 500)
    |> Map.get("Fault")
    |> Map.get("Code")
    |> Map.get("Subcode")
    |> Map.get("Value")
    assert error_message == "ter:InvalidArgVal"
  end

    
end
