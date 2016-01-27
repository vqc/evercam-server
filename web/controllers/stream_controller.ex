defmodule EvercamMedia.StreamController do
  use EvercamMedia.Web, :controller

  def rtmp(conn, params) do
    conn
    |> put_status(request_stream(params["name"], params["token"], :kill))
    |> text("")
  end

  def hls(conn, params) do
    request_stream(params["camera_id"], params["token"], :check)
    |> hls_response(conn, params)
  end

  defp hls_response(200, conn, params) do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> redirect(external: "#{Application.get_env(:evercam_media, :hls_url)}/hls/#{params["camera_id"]}/index.m3u8")
  end

  defp hls_response(status, conn, _params) do
    conn
    |> put_status(status)
    |> text("")
  end

  def ts(conn, params) do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> redirect(external: "#{Application.get_env(:evercam_media, :hls_url)}/hls/#{params["camera_id"]}/#{params["filename"]}")
  end

  defp request_stream(camera_exid, token, command) do
    try do
      [username, password, rtsp_url, _] = Util.decode_request_token(token)
      camera = Camera.get(camera_exid)
      check_auth(camera, username, password)
      stream(camera_exid, rtsp_url, token, command)
      200
    rescue
      error ->
        Util.error_handler(error)
        401
    end
  end

  defp check_auth(camera, username, password) do
    if camera.config["auth"]["basic"]["username"] != username ||
      camera.config["auth"]["basic"]["password"] != password do
      raise FunctionClauseError
    end
  end

  defp stream(camera_exid, rtsp_url, token, :check) do
    cmd = Porcelain.shell("ps -ef | grep ffmpeg | grep #{rtsp_url} | grep -v grep | awk '{print $2}'")
    pids = String.split cmd.out
    if length(pids) == 0 do
      construct_ffmpeg_command(camera_exid, rtsp_url, token) |> Porcelain.spawn_shell
    end
  end

  defp stream(camera_exid, rtsp_url, token, :kill) do
    cmd = Porcelain.shell("ps -ef | grep ffmpeg | grep #{rtsp_url} | grep -v grep | awk '{print $2}'")
    pids = String.split cmd.out
    Enum.each pids, &Porcelain.shell("kill -9 #{&1}")
    construct_ffmpeg_command(camera_exid, rtsp_url, token) |> Porcelain.spawn_shell
  end

  defp construct_ffmpeg_command(camera_exid, rtsp_url, token) do
    "ffmpeg -rtsp_transport tcp -i #{rtsp_url} -f lavfi -i aevalsrc=0 -vcodec copy -acodec aac -map 0:0 -map 1:0 -shortest -strict experimental -f flv rtmp://localhost:1935/live/#{camera_exid}?token=#{token} &"
  end
end
