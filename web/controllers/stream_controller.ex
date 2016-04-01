defmodule EvercamMedia.StreamController do
  use EvercamMedia.Web, :controller

  @hls_dir "/tmp/hls"
  @hls_url Application.get_env(:evercam_media, :hls_url)

  def rtmp(conn, params) do
    conn
    |> put_status(request_stream(params["camera_id"], params["name"], :kill))
    |> text("")
  end

  def hls(conn, params) do
    request_stream(params["camera_id"], params["token"], :check)
    |> hls_response(conn, params)
  end

  defp hls_response(200, conn, params) do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> redirect(external: "#{@hls_url}/#{params["token"]}/index.m3u8")
  end

  defp hls_response(status, conn, _params) do
    conn
    |> put_status(status)
    |> text("")
  end

  def ts(conn, params) do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> redirect(external: "#{@hls_url}/#{params["token"]}/#{params["filename"]}")
  end

  defp request_stream(camera_exid, token, command) do
    try do
      [username, password, rtsp_url] = Util.decode(token)
      camera = Camera.get(camera_exid)
      check_auth(camera, username, password)
      stream(rtsp_url, token, command)
      200
    rescue
      error ->
        Util.error_handler(error)
        401
    end
  end

  defp check_auth(camera, username, password) do
    if Camera.username(camera) != username || Camera.password(camera) != password do
      raise "Invalid credentials used to request the video stream"
    end
  end

  defp stream(rtsp_url, token, :check) do
    if length(ffmpeg_pids(rtsp_url)) == 0 do
      construct_ffmpeg_command(rtsp_url, token) |> Porcelain.spawn_shell
    end
    sleep_until_hls_playlist_exists(token)
  end

  defp stream(rtsp_url, token, :kill) do
    Enum.each(ffmpeg_pids(rtsp_url), &Porcelain.shell("kill -9 #{&1}"))
    construct_ffmpeg_command(rtsp_url, token) |> Porcelain.spawn_shell
  end

  defp sleep_until_hls_playlist_exists(token), do: do_sleep_until_hls_playlist_exists(token, 0)

  defp do_sleep_until_hls_playlist_exists(_token, retry) when retry > 30, do: :noop
  defp do_sleep_until_hls_playlist_exists(token, retry) do
    unless File.exists?("#{@hls_dir}/#{token}/index.m3u8") do
      :timer.sleep(500)
      do_sleep_until_hls_playlist_exists(token, retry + 1)
    end
  end

  defp ffmpeg_pids(rtsp_url) do
    Porcelain.shell("ps -ef | grep ffmpeg | grep '#{rtsp_url}' | grep -v grep | awk '{print $2}'").out
    |> String.split
  end

  defp construct_ffmpeg_command(rtsp_url, token) do
    "ffmpeg -rtsp_transport tcp -i '#{rtsp_url}' -f lavfi -i aevalsrc=0 -vcodec copy -acodec aac -map 0:0 -map 1:0 -shortest -strict experimental -f flv rtmp://localhost:1935/live/#{token} &"
  end
end
