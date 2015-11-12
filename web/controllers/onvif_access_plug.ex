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
    assign(conn, :onvif_access_info, access_info)
  end

end
