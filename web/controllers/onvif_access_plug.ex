defmodule EvercamMedia.ONVIFAccessPlug do
  import Plug.Conn

  def init(_opts) do
  end

  def call(conn, _) do
    access_info =  case conn.query_params do
                     %{"auth" => _auth, "url" => _url} -> conn.query_params
                     %{"id" => id} -> Camera.get_camera_info id
                     _ -> conn
                          |> resp(400, Poison.encode!(%{ error: %{ message: "Missing camera access info" }}, []))
                          |> send_resp()
                          |> halt()
                   end

    parameters = conn.query_params
                 |> Enum.filter(fn({key, value}) -> key != "id" and key != "url" and key != "auth" end)
                 |> Enum.reduce("", fn({key,value}, acc) -> "#{acc}<#{key}>#{value}</#{key}>" end)

    conn
    |> assign(:onvif_parameters, parameters)
    |> assign(:onvif_access_info, access_info)
  end

end 
