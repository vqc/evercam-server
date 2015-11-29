defmodule EvercamMedia.ONVIFClient do
  require Logger
  require Record
  Record.defrecord :xmlElement, Record.extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl")
  Record.defrecord :xmlText, Record.extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl")
  Record.defrecord :xmlAttribute, Record.extract(:xmlAttribute, from_lib: "xmerl/include/xmerl.hrl")

  def request(%{"url" => base_url, "auth" => auth}, service, operation, parameters \\ "") do
    url = "#{base_url}/onvif/#{service}"
    namespace =  case service do
                   "PTZ" -> "tptz"
                   "device_service" -> "tds"
                   "Media" -> "trt"
                   "Display" -> "tls"
                   "Events" -> "tev"
                   "Analytics" -> "tan"
                   "AnalyticsDevice" -> "tad"
                   "DeviceIO" -> "tmd"
                   "Imaging" -> "timg"
                   "Search" -> "tse"
                   "Replay" -> "trp"
                   "Recording" -> "trc"
                   "Storage" -> "tst"
                   "Receiver" -> "trv"
                   "Network" -> "dn"
                  end

    [username, password] = auth |> String.split ":" 
    request = gen_onvif_request(namespace, operation, username, password, parameters)
    response = HTTPotion.post url, [body: request, headers: ["Content-Type": "application/soap+xml", "SOAPAction": "http://www.w3.org/2003/05/soap-envelope"]]

    {xml, _rest} = response.body |> to_char_list |> :xmerl_scan.string

    if HTTPotion.Response.success?(response) do
      {:ok, "/env:Envelope/env:Body/#{namespace}:#{operation}Response" |> to_char_list |> :xmerl_xpath.string(xml) |> parse_elements}
    else
      Logger.error "Error invoking #{operation}. URL: #{url} auth: #{auth}. Request: #{inspect request}. Response #{inspect response}."
      {:error, response.status_code, "/env:Envelope/env:Body" |> to_char_list |> :xmerl_xpath.string(xml) |> parse_elements}
    end
  end

  defp gen_onvif_request(namespace, operation, username, password, parameters) do
    wsdl_url =
      case namespace do
        "tptz" -> "http://www.onvif.org/ver20/ptz/wsdl"
        "tds" -> "http://www.onvif.org/ver20/device/wsdl"
        "trt" -> "http://www.onvif.org/ver10/media/wsdl"
        "tls" -> "http://www.onvif.org/ver10/display/wsdl"
        "tev" -> "http://www.onvif.org/ver10/events/wsdl"  
        "timg" -> "http://www.onvif.org/ver20/imaging/wsdl"  
        "tan" -> "http://www.onvif.org/ver20/analytics/wsdl"
        "tad" -> "http://www.onvif.org/ver10/analyticsdevice/wsdl" 
        "tst" -> "http://www.onvif.org/ver10/storage/wsdl" 
        "dn" -> "http://www.onvif.org/ver10/network/wsdl" 
        "tmd" -> "http://www.onvif.org/ver10/deviceIO/wsdl" 
        "trc" -> "http://www.onvif.org/ver10/recording/wsdl" 
        "tse" -> "http://www.onvif.org/ver10/search/wsdl" 
        "trp" -> "http://www.onvif.org/ver10/replay/wsdl"
        "trv" -> "http://www.onvif.org/ver10/receiver/wsdl" 
       end

    {wsse_username, wsse_password, wsse_nonce, wsse_created} = get_wsse_header_data(username,password)

    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://www.w3.org/2003/05/soap-envelope\"
    xmlns:wsse=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd\"
    xmlns:wsu=\"http://docs.oasis-open.org/wss/2004/01/oasis=200401-wss-wssecurity-utility-1.0.xsd\">
    <SOAP-ENV:Header><wsse:Security><wsse:UsernameToken>
    <wsse:Username>#{wsse_username}</wsse:Username>
    <wsse:Password Type=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest\">#{wsse_password}</wsse:Password>
    <wsse:Nonce>#{wsse_nonce}</wsse:Nonce>
    <wsu:Created>#{wsse_created}</wsu:Created></wsse:UsernameToken>
    </wsse:Security></SOAP-ENV:Header><SOAP-ENV:Body>
    <#{namespace}:#{operation} xmlns:#{namespace}=\"#{wsdl_url}\">#{parameters}</#{namespace}:#{operation}>
    </SOAP-ENV:Body></SOAP-ENV:Envelope>"
  end

  #### WSSE

  def get_wsse_header_data(user, password) do
    {a, b, c} = :os.timestamp
    :random.seed(a, b, c)
    nonce = nonce(20, []) |> to_string
    created = format_date_time(:erlang.localtime)
    digest = :crypto.hash(:sha, nonce <> created <> password) |> to_string
    {user, Base.encode64(digest), Base.encode64(nonce), created}
  end

  defp format_date_time({{year, month, day}, {hour, minute, second}}) do
    :io_lib.format("~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0BZ", [year, month, day, hour, minute, second]) |> List.flatten |> to_string
  end

  defp nonce(0,l) do
    l ++ [:random.uniform(255)]
  end

  defp nonce(n,l) do
    nonce(n - 1, l ++ [:random.uniform(255)])
  end

  #### XML Parsing

  def parse_elements(event_elements) do
    [response] = Enum.map(event_elements, fn(event_element) ->
      parse(xmlElement(event_element, :content))
    end)
    if Map.size(response) == 0 do
      :ok
    else
      response
    end
  end

  defp parse(node) do
    cond do
      Record.is_record(node, :xmlElement) ->
        name = case xmlElement(node, :name) |> to_string |> String.split ":" do
                 [_ns,name] -> name
                 [name] -> name
               end
        content = xmlElement(node, :content)
        case xmlElement(node, :attributes) do
          [] -> Map.put(%{}, name, parse(content))
          attributes ->  case parse(content) do 
                           value when is_map(value) -> Map.put(%{}, name, value |> Map.merge(parse(attributes)))
                           value -> Map.put(%{}, name, value)
                         end
        end
      Record.is_record(node, :xmlAttribute) ->
        name = xmlAttribute(node, :name) |> to_string
        value = xmlAttribute(node, :value) |> to_string
        Map.put(%{}, name, value)

      Record.is_record(node, :xmlText) ->
        case xmlText(node, :value) |> to_string do
          "\n" -> %{}
          value -> Map.put(%{}, "#text", value)
        end

      is_list(node) ->
        case Enum.map(node, &(parse(&1))) do
          [text_content] when is_map(text_content) ->
            Map.get(text_content, "#text", text_content)

          elements ->
            Enum.reduce(elements, %{}, fn(x, acc) ->
              if is_map(x) do
                Map.merge(acc, x, fn(_key, v1, v2) ->
                  case v1 do
                    nil -> v2
                    v when is_list(v) -> v ++ [v2]
                    _ -> [v1, v2]
                  end
                end)
              else
                acc
              end
            end)
        end
      true -> "Not supported to parse #{inspect node}"
    end
  end
end
