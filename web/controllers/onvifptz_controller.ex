defmodule EvercamMedia.ONVIFPTZController do
  use Phoenix.Controller
  alias EvercamMedia.ONVIFPTZ
  require Logger

  def status(conn, %{"id" => id}) do
    {:ok, response} = id
    |> Camera.get_camera_info 
    |> ONVIFPTZ.get_status "Profile_1"
    default_respond(conn, 200, response)
  end

  def nodes(conn, %{"id" => id}) do
    {:ok, response} = id
    |> Camera.get_camera_info 
    |> ONVIFPTZ.get_nodes
    default_respond(conn, 200, response)
  end

  def configurations(conn, %{"id" => id}) do
    {:ok, response} = id
    |> Camera.get_camera_info 
    |> ONVIFPTZ.get_configurations
    default_respond(conn, 200, response)
  end

  def presets(conn, %{"id" => id}) do
    {:ok, response} = id
    |> Camera.get_camera_info 
    |> ONVIFPTZ.get_presets "Profile_1"
    default_respond(conn, 200, response)
  end

  def stop(conn, %{"id" => id}) do
    {:ok, response} = id
    |> Camera.get_camera_info 
    |> ONVIFPTZ.stop "Profile_1"
    default_respond(conn, 200, response)
  end

  def home(conn, %{"id" => id}) do
    {:ok, response} = id
    |> Camera.get_camera_info 
    |> ONVIFPTZ.goto_home_position "Profile_1"
    default_respond(conn, 200, response)
  end

  def sethome(conn, %{"id" => id}) do
    {:ok, response} = id
    |> Camera.get_camera_info 
    |> ONVIFPTZ.set_home_position "Profile_1"
    default_respond(conn, 200, response)
  end

  def gotopreset(conn, %{"id" => id, "preset_token" => token}) do
    {:ok, response} = id
    |> Camera.get_camera_info 
    |> ONVIFPTZ.goto_preset("Profile_1", token)
    default_respond(conn, 200, response)
  end

  def setpreset(conn, %{"id" => id, "preset_token" => token}) do
    {:ok, response} = id
    |> Camera.get_camera_info 
    |> ONVIFPTZ.set_preset("Profile_1", "", token)
    default_respond(conn, 200, response)
  end

  def createpreset(conn, %{"id" => id, "preset_name" => name}) do
    {:ok, response} = id
    |> Camera.get_camera_info 
    |> ONVIFPTZ.set_preset("Profile_1", name)
    default_respond(conn, 200, response)
  end

  def continuousmove(conn, %{"id" => id, "direction" => direction}) do
    velocity =
      case direction do
        "left" -> [x: -0.1, y: 0.0]
        "right" -> [x: 0.1, y: 0.0]
        "up" -> [x: 0.0, y: 0.1]
        "down" -> [x: 0.0, y: -0.1]
        _ -> [x: 0.0, y: 0.0]
      end
    {:ok, response} = id
    |> Camera.get_camera_info 
    |> ONVIFPTZ.continuous_move("Profile_1", velocity)
    default_respond(conn, 200, response)
  end

  def continuouszoom(conn, %{"id" => id, "mode" => mode}) do
    velocity =
      case mode do
        "in" -> [zoom: 0.01]
        "out" -> [zoom: -0.01]
        _ -> [zoom: 0.0]
      end
    {:ok, response} = id
    |> Camera.get_camera_info 
    |> ONVIFPTZ.continuous_move("Profile_1", velocity)
    default_respond(conn, 200, response)
  end

  def relativemove(conn, %{"id" => id} = params) do

    left = Map.get(params, "left", "0") |> String.to_integer
    right = Map.get(params, "right", "0") |> String.to_integer
		up = Map.get(params, "up", "0") |> String.to_integer
    down = Map.get(params, "down", "0") |> String.to_integer
    zoom = Map.get(params, "zoom", "0") |> String.to_integer
    x =
      cond do
        right > left -> right
        true -> -left
      end
    y =
      cond do
        down > up -> down
        true -> -up
      end
    
    {:ok, response} = id
    |> Camera.get_camera_info 
    |> ONVIFPTZ.relative_move(
      "Profile_1",
      [x: x / 100.0, y: y / 100.0, zoom: zoom / 100.0]
    )
    default_respond(conn, 200, response)
  end

  defp default_respond(conn, code, response) do
    conn
    |> put_status(code)
    |> put_resp_header("access-control-allow-origin", "*")
    |> json response
  end

end
