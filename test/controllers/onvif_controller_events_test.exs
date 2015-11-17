defmodule EvercamMedia.ONVIFControllerEventsTest do
  use EvercamMedia.ConnCase

  @access_params "url=http://149.13.244.32:8100&auth=admin:mehcam"

  test "GET /v1/onvif/v20/Events/GetServiceCapabilities, returns something" do
    conn = get conn(), "/v1/onvif/v20/Events/GetServiceCapabilities?#{@access_params}"
    response = json_response(conn, 200)
    subscription_policy_support = inspect json_response(conn, 200)
    |> Map.get("Capabilities")
    |> Map.get("WSSubscriptionPolicySupport")
    assert subscription_policy_support == "\"true\""
  end
    
 
    
end
