defmodule EvercamMedia.SnapshotController do
  use Phoenix.Controller
  use Timex
  use Calendar
  alias EvercamMedia.Util
  alias EvercamMedia.Snapshot.CamClient
  alias EvercamMedia.Snapshot.DBHandler
  alias EvercamMedia.Snapshot.S3Upload
  require Logger
  # TODO: refactor the functions in this module, there's
  # a lot of duplication with db_handler functions

  def show(conn, params) do
    timestamp = DateTime.now_utc |> DateTime.Format.unix
    [code, response] = [200, ConCache.get(:cache, params["id"])]
    unless response do
      [code, response] = snapshot(params["id"], params["token"], timestamp, false)
    end
    show_respond(conn, code, response, params["id"], timestamp)
  end

  def show_last(conn, params) do
    timestamp = DateTime.now_utc |> DateTime.Format.unix
    camera_exid = params["id"]
    camera_exid_last = "#{camera_exid}_last"
    [code, response] = [200, ConCache.get(:cache, camera_exid_last)]
    unless response do
      [code, response] = snapshot(params["id"], params["token"], timestamp, false)
    end
    show_respond(conn, code, response, params["id"], timestamp)
  end

  def show_previous(conn, params) do
    timestamp = DateTime.now_utc |> DateTime.Format.unix
    camera_exid = params["id"]
    camera_exid_previous = "#{camera_exid}_previous"
    [code, response] = [200, ConCache.get(:cache, camera_exid_previous)]
    unless response do
      [code, response] = snapshot(params["id"], params["token"], timestamp, false)
    end
    show_respond(conn, code, response, params["id"], timestamp)
  end

  def create(conn, params) do
    timestamp = DateTime.now_utc |> DateTime.Format.unix
    [code, response] = [200, ConCache.get(:cache, params["id"])]
    unless response do
      [code, response] = snapshot(params["id"], params["token"], timestamp, true, params["notes"])
    end
    create_respond(conn, code, response, params["with_data"])
  end

  def test(conn, params) do
    [code, response] =
      get_snapshot_response(
        params["cam_username"],
        params["cam_password"],
        "#{params["external_url"]}/#{params["jpg_url"]}",
        params["vendor_id"]
      )

    test_respond(conn, code, response)
  end

  defp show_respond(conn, 200, response, camera_id, timestamp) do
    Util.broadcast_snapshot(camera_id, response[:image], timestamp)

    conn
    |> put_status(200)
    |> put_resp_header("content-type", "image/jpg")
    |> put_resp_header("access-control-allow-origin", "*")
    |> text response[:image]
  end

  defp show_respond(conn, code, response, _, _) do
    conn
    |> put_status(code)
    |> put_resp_header("access-control-allow-origin", "*")
    |> json response
  end

  defp create_respond(conn, 200, response, "true") do
    data = "data:image/jpeg;base64,#{Base.encode64(response[:image])}"

    conn
    |> put_status(200)
    |> put_resp_header("access-control-allow-origin", "*")
    |> json %{created_at: response[:timestamp], notes: response[:notes], data: data}
  end

  defp create_respond(conn, 200, response, _) do
    conn
    |> put_status(200)
    |> put_resp_header("access-control-allow-origin", "*")
    |> json %{created_at: response[:timestamp], notes: response[:notes]}
  end

  defp create_respond(conn, code, response, _) do
    conn
    |> put_status(code)
    |> put_resp_header("access-control-allow-origin", "*")
    |> json response
  end

  defp test_respond(conn, 200, response) do
    data = "data:image/jpeg;base64,#{Base.encode64(response[:image])}"

    conn
    |> put_status(200)
    |> put_resp_header("access-control-allow-origin", "*")
    |> json %{data: data, status: "ok"}
  end

  defp test_respond(conn, code, response) do
    conn
    |> put_status(code)
    |> put_resp_header("access-control-allow-origin", "*")
    |> json response
  end

  defp snapshot(camera_id, token, timestamp, store_snapshot, notes \\ "Evercam Proxy") do
    camera = EvercamMedia.Repo.one! Camera.by_exid_with_vendor(camera_id)
    unless notes do
      notes = "Evercam Proxy"
    end
    if camera.vendor_model do
      vendor_exid = camera.vendor_model.vendor.exid
    else
      vendor_exid = ""
    end

    args = %{
      camera_exid: camera.exid,
      vendor_exid: vendor_exid,
      url: Camera.snapshot_url(camera),
      username: Camera.username(camera),
      password: Camera.password(camera),
      store_snapshot: store_snapshot,
      timestamp: timestamp,
      notes: notes
    }
    get_snapshot(args)
  end

  defp get_snapshot_response(username, password, url, vendor_exid) do
    args = %{
      vendor_exid: vendor_exid,
      url: url,
      username: username,
      password: password
    }

    case response = CamClient.fetch_snapshot(args) do
      {:ok, data} ->
        [200, %{image: data}]
      {:error, %{reason: "Response not a jpeg image", response: response}} ->
        [504, %{message: "Camera didn't respond with an image.", response: response}]
      {:error, %HTTPoison.Response{}} ->
        [504, %{message: response.body}]
      {:error, %HTTPoison.Error{id: nil, reason: :timeout}} ->
        [504, %{message: "Camera response timed out."}]
      {:error, %HTTPoison.Error{}} ->
        [504, %{message: "Camera seems to be offline."}]
      _error ->
        [500, %{message: "Sorry, we dropped the ball."}]
    end
  end

  defp get_snapshot(args) do
    response = CamClient.fetch_snapshot(args)
    parse_camera_response(args, response, args[:store_snapshot])
  end

  defp parse_camera_response(args, {:ok, data}, true) do
    spawn fn ->
      Logger.debug "Uploading snapshot to S3 for camera #{args[:camera_exid]} taken at #{args[:timestamp]}"
      S3Upload.put(args[:camera_exid], args[:timestamp], data)
    end
    spawn fn ->
      try do
        DBHandler.update_camera_status(args[:camera_exid], args[:timestamp], true, true)
        |> DBHandler.save_snapshot_record(args[:timestamp], nil, args[:notes])
      rescue
        error ->
          Util.error_handler(error)
      end
    end
    [200, %{image: data, timestamp: args[:timestamp], notes: args[:notes]}]
  end

  defp parse_camera_response(args, {:ok, data}, false) do
    spawn fn ->
      try do
        DBHandler.update_camera_status("#{args[:camera_exid]}", args[:timestamp], true)
      rescue
        error ->
          Util.error_handler(error)
      end
    end
    [200, %{image: data}]
  end

  defp parse_camera_response(args, {:error, error}, _store_snapshot) do
    camera_exid = args[:camera_exid]
    timestamp = args[:timestamp]
    if is_map(error) do
      reason = Map.get(error, :reason)
    else
      reason = error
    end
    case reason do
      :system_limit ->
        Logger.error "[#{camera_exid}] [snapshot_error] [system_limit] Traceback."
        Util.error_handler(error)
        [500, %{message: "Sorry, we dropped the ball."}]
      :closed ->
        Logger.error "[#{camera_exid}] [snapshot_error] [closed] Traceback."
        Util.error_handler(error)
        [504, %{message: "Connection closed."}]
      :emfile ->
        Logger.error "[#{camera_exid}] [snapshot_error] [emfile] Traceback."
        Util.error_handler(error)
        [500, %{message: "Sorry, we dropped the ball."}]
      :nxdomain ->
        Logger.info "[#{camera_exid}] [snapshot_error] [nxdomain]"
        DBHandler.update_camera_status("#{camera_exid}", timestamp, false)
        [504, %{message: "Non-existant domain."}]
      :ehostunreach ->
        Logger.info "[#{camera_exid}] [snapshot_error] [ehostunreach]"
        DBHandler.update_camera_status("#{camera_exid}", timestamp, false)
        [504, %{message: "No route to host."}]
      :enetunreach ->
        Logger.info "[#{camera_exid}] [snapshot_error] [enetunreach]"
        DBHandler.update_camera_status("#{camera_exid}", timestamp, false)
        [504, %{message: "Network unreachable."}]
      :timeout ->
        Logger.info "[#{camera_exid}] [snapshot_error] [timeout]"
        [504, %{message: "Camera response timed out."}]
      :connect_timeout ->
        Logger.info "[#{camera_exid}] [snapshot_error] [connect_timeout]"
        DBHandler.update_camera_status("#{camera_exid}", timestamp, false)
        [504, %{message: "Connection to the camera timed out."}]
      :econnrefused ->
        Logger.info "[#{camera_exid}] [snapshot_error] [econnrefused]"
        DBHandler.update_camera_status("#{camera_exid}", timestamp, false)
        [504, %{message: "Connection refused."}]
      "Response not a jpeg image" ->
        Logger.info "[#{camera_exid}] [snapshot_error] [not_a_jpeg]"
        [502, %{message: "Camera didn't respond with an image.", response: error[:response]}]
      _reason ->
        Logger.info "[#{camera_exid}] [snapshot_error] [unhandled] #{inspect error}"
        [500, %{message: "Sorry, we dropped the ball."}]
    end
  end

  defp check_token_expiry(time) do
    token_time = DateFormat.parse! time, "{ISOz}"
    token_time = Date.shift token_time, mins: 5

    if Date.now > token_time do
      raise FunctionClauseError
    end
  end
end
