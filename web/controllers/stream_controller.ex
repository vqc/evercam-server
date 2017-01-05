defmodule EvercamMedia.StreamController do
  use EvercamMedia.Web, :controller

  @hls_dir "/tmp/hls"
  @hls_url Application.get_env(:evercam_media, :hls_url)

  def rtmp(conn, params) do
    requester_ip = user_request_ip(conn)
    conn
    |> put_status(request_stream(params["camera_id"], params["name"], requester_ip, :kill))
    |> text("")
  end

  def hls(conn, params) do
    requester_ip = user_request_ip(conn)
    code = request_stream(params["camera_id"], params["token"], requester_ip, :check)
    hls_response(code, conn, params)
  end

  defp hls_response(200, conn, params) do
    conn
    |> redirect(external: "#{@hls_url}/#{params["token"]}/index.m3u8")
  end

  defp hls_response(status, conn, _params) do
    conn
    |> put_status(status)
    |> text("")
  end

  def ts(conn, params) do
    conn
    |> redirect(external: "#{@hls_url}/#{params["token"]}/#{params["filename"]}")
  end

  defp request_stream(camera_exid, token, ip, command) do
    try do
      [username, password, rtsp_url] = Util.decode(token)
      camera = Camera.get(camera_exid)
      check_auth(camera, username, password)
      check_port(camera)
      stream(rtsp_url, token, camera.id, ip, command)
      200
    rescue
      error ->
        Util.error_handler(error)
        401
    end
  end

  defp check_port(camera) do
    host = Camera.host(camera)
    port = Camera.port(camera, "external", "rtsp")
    if !Util.port_open?(host, "#{port}") do
      raise "Invalid RTSP port to request the video stream"
    end
  end

  defp check_auth(camera, username, password) do
    if Camera.username(camera) != username || Camera.password(camera) != password do
      raise "Invalid credentials used to request the video stream"
    end
  end

  defp stream(rtsp_url, token, camera_id, ip, :check) do
    if length(ffmpeg_pids(rtsp_url)) == 0 do
      start_stream(rtsp_url, token, camera_id, ip, "hls")
    end
    sleep_until_hls_playlist_exists(token)
  end

  defp stream(rtsp_url, token, camera_id, ip, :kill) do
    kill_streams(rtsp_url, camera_id)
    start_stream(rtsp_url, token, camera_id, ip, "rtmp")
  end

  defp start_stream(rtsp_url, token, camera_id, ip, action) do
    rtsp_url
    |> construct_ffmpeg_command(token)
    |> Porcelain.spawn_shell
    spawn(fn -> insert_meta_data(rtsp_url, action, camera_id, ip, token) end)
  end

  defp kill_streams(rtsp_url, camera_id) do
    rtsp_url
    |> ffmpeg_pids
    |> Enum.each(fn(pid) -> Porcelain.shell("kill -9 #{pid}") end)
    spawn(fn -> MetaData.delete_by_camera_id(camera_id) end)
  end

  defp sleep_until_hls_playlist_exists(token, retry \\ 0)

  defp sleep_until_hls_playlist_exists(_token, retry) when retry > 30, do: :noop
  defp sleep_until_hls_playlist_exists(token, retry) do
    unless File.exists?("#{@hls_dir}/#{token}/index.m3u8") do
      :timer.sleep(500)
      sleep_until_hls_playlist_exists(token, retry + 1)
    end
  end

  defp ffmpeg_pids(rtsp_url) do
    Porcelain.shell("ps -ef | grep ffmpeg | grep '#{rtsp_url}' | grep -v grep | awk '{print $2}'").out
    |> String.split
  end

  defp construct_ffmpeg_command(rtsp_url, token) do
    "ffmpeg -rtsp_transport tcp -i '#{rtsp_url}' -f lavfi -i aevalsrc=0 -vcodec copy -acodec aac -map 0:0 -map 1:0 -shortest -strict experimental -f flv rtmp://localhost:1935/live/#{token} &"
  end

  defp insert_meta_data(rtsp_url, action, camera_id, ip, token) do
    rtsp_url
    |> ffmpeg_pids
    |> Enum.each(fn(pid) ->
      meta_params = construct_params(camera_id, action, ip, pid, rtsp_url, token)
      MetaData.insert_meta(meta_params)
    end)
  end

  defp construct_params(camera_id, action, ip, pid, rtsp_url, token) do
    %{
      camera_id: camera_id,
      action: action,
      process_id: pid,
      extra: %{ip: ip, rtsp_url: rtsp_url, token: token}
    }
  end
end
