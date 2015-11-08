defmodule DeviceManagementTest do
  use ExUnit.Case
  alias EvercamMedia.ONVIFDeviceManagement

  test "device_management_request method on hikvision camera" do
    {:ok, response} = ONVIFDeviceManagement.device_management_request(%{url: "http://149.13.244.32:8100", auth: "admin:mehcam"}, "GetDeviceInformation")

    assert Map.get(response, "Manufacturer")  == "HIKVISION"
    assert Map.get(response, "Model") == "DS-2DF7286-A"
    assert Map.get(response, "FirmwareVersion") == "V5.1.8 build 140616"
    assert Map.get(response, "SerialNumber") == "DS-2DF7286-A20140705CCWR471699220B"
    assert Map.get(response, "HardwareId") == "88"
  end

end
