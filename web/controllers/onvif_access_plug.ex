defmodule EvercamMedia.ONVIFAccessPlug do
  import Plug.Conn

  def init(_opts) do
  end

  def call(conn, _) do
    access_info =  case conn.query_params do
                     %{"auth" => _auth, "url" => _url} -> conn.query_params
                     _ -> %{"id" => id} = conn.params
                          Camera.get_camera_info id
                   end
    parameters = case conn.path_info do
                   ["v1", "onvif", "v20", _service, _operation | parameters_list] -> build_parameters parameters_list
                   _ -> ""  
                 end
    conn
    |> assign(:onvif_parameters, parameters)
    |> assign(:onvif_access_info, access_info)
  end


  def build_parameters(parameters_list), do: build_parameters(parameters_list, "")
  def build_parameters([], acc), do: acc
  def build_parameters([param | rest], acc) do
    [param_name, value] = param |> String.split "="
    build_parameters(rest, "#{acc}<#{param_name}>#{value}</#{param_name}>")
  end

end 
