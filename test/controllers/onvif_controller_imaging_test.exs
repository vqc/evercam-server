defmodule EvercamMedia.ONVIFControllerImagingTest do
  use EvercamMedia.ConnCase

  @access_params "url=http://149.13.244.32:8100&auth=admin:mehcam"
 
  test "GET /v1/onvif/v20/DeviceIO/GetImagingSettings" do
    conn = get conn(), "/v1/onvif/v20/Imaging/GetImagingSettings?#{@access_params}&VideoSourceToken=VideoSource_1"
    brightness = json_response(conn, 200)
    |> Map.get("ImagingSettings")
    |> Map.get("Brightness")
    assert brightness == "50"
  end

  test "GET /v1/onvif/v20/DeviceIO/GetServiceCapabilities" do
    conn = get conn(), "/v1/onvif/v20/Imaging/GetServiceCapabilities?#{@access_params}"
    image_stabilization = json_response(conn, 200)
    |> Map.get("Capabilities")
    |> Map.get("ImageStabilization")
    assert image_stabilization == "false"
  end 
    
end
