defmodule EvercamMedia.ONVIFControllerEventsTest do
  use EvercamMedia.ConnCase
  use ExVCR.Mock, options: [clear_mock: true]

  @access_params "url=http://recorded_response&auth=admin:mehcam"

  test "GET /v1/onvif/v20/Events/GetServiceCapabilities, returns something" do
    use_cassette "ev_get_service_capabilities" do 
      conn = get conn(), "/v1/onvif/v20/Events/GetServiceCapabilities?#{@access_params}"
      subscription_policy_support = json_response(conn, 200) |> Map.get("Capabilities") |> Map.get("WSSubscriptionPolicySupport")
      assert subscription_policy_support == "true"
    end
  end

  test "GET /v1/onvif/v20/Events/GetEventProperties, returns something" do
    use_cassette "get_event_properties" do
      conn = get conn(), "/v1/onvif/v20/Events/GetEventProperties?#{@access_params}"
      fixed_topic_set = json_response(conn, 200) |> Map.get("FixedTopicSet")
      assert fixed_topic_set == "true"
    end
  end
end
