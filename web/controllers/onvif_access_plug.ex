defmodule EvercamMedia.ONVIFAccessPlug do
  import Plug.Conn

  def init(_opts) do
  end

  def call(conn, _) do
    %{"id" => id} = conn.params
    assign(conn, :onvif_access_info, Camera.get_camera_info id)
  end

end
