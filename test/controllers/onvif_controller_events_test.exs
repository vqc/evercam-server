defmodule EvercamMedia.ONVIFControllerEventsTest do
  use EvercamMedia.ConnCase

  @moduletag :external
  @access_params "url=http://149.13.244.32:8100&auth=admin:mehcam"

  test "GET /v1/onvif/v20/Events/GetServiceCapabilities, returns something" do
    conn = get conn(), "/v1/onvif/v20/Events/GetServiceCapabilities?#{@access_params}"
    subscription_policy_support = json_response(conn, 200) |> Map.get("Capabilities") |> Map.get("WSSubscriptionPolicySupport")
    assert subscription_policy_support == "true"
  end

  test "GET /v1/onvif/v20/Events/GetEventProperties, returns something" do
    conn = get conn(), "/v1/onvif/v20/Events/GetEventProperties?#{@access_params}"
    fixed_topic_set = json_response(conn, 200) |> Map.get("FixedTopicSet")
    assert fixed_topic_set == "true"
  end
end
