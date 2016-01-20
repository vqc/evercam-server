defmodule EvercamMedia.SnapshotController do
  use EvercamMedia.Web, :controller
  use Calendar
  alias EvercamMedia.Snapshot.CamClient
  alias EvercamMedia.Snapshot.DBHandler
  alias EvercamMedia.Snapshot.S3

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
      test_snapshot_response(
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
    |> text(response[:image])
  end

  defp show_respond(conn, code, response, _, _) do
    conn
    |> put_status(code)
    |> put_resp_header("access-control-allow-origin", "*")
    |> json(response)
  end

  defp create_respond(conn, 200, response, "true") do
    data = "data:image/jpeg;base64,#{Base.encode64(response[:image])}"

    conn
    |> put_status(200)
    |> put_resp_header("access-control-allow-origin", "*")
    |> json(%{created_at: response[:timestamp], notes: response[:notes], data: data})
  end

  defp create_respond(conn, 200, response, _) do
    conn
    |> put_status(200)
    |> put_resp_header("access-control-allow-origin", "*")
    |> json(%{created_at: response[:timestamp], notes: response[:notes]})
  end

  defp create_respond(conn, code, response, _) do
    conn
    |> put_status(code)
    |> put_resp_header("access-control-allow-origin", "*")
    |> json(response)
  end

  defp test_respond(conn, 200, response) do
    data = "data:image/jpeg;base64,#{Base.encode64(response[:image])}"

    conn
    |> put_status(200)
    |> put_resp_header("access-control-allow-origin", "*")
    |> json(%{data: data, status: "ok"})
  end

  defp test_respond(conn, code, response) do
    conn
    |> put_status(code)
    |> put_resp_header("access-control-allow-origin", "*")
    |> json(response)
  end

  defp snapshot(camera_id, _token, timestamp, store_snapshot, notes \\ "Evercam Proxy") do
    camera = EvercamMedia.Repo.one! Camera.by_exid_with_vendor(camera_id)
    unless notes do
      notes = "Evercam Proxy"
    end

    args = %{
      camera_exid: camera.exid,
      is_online: camera.is_online,
      vendor_exid: Camera.vendor_exid(camera),
      url: Camera.snapshot_url(camera),
      username: Camera.username(camera),
      password: Camera.password(camera),
      store_snapshot: store_snapshot,
      timestamp: timestamp,
      notes: notes
    }
    get_snapshot(args)
  end

  defp test_snapshot_response(username, password, url, vendor_exid) do
    args = %{
      vendor_exid: vendor_exid,
      url: url,
      username: username,
      password: password
    }

    case response = CamClient.fetch_snapshot(args) do
      {:ok, data} ->
        [200, %{image: data}]
      {:error, %{reason: :not_found, response: response}} ->
        [504, %{message: "Camera url is not found.", response: response}]
      {:error, %{reason: :device_error, response: response}} ->
        [504, %{message: "Camera responded with a Device Error message.", response: response}]
      {:error, %{reason: :device_busy, response: response}} ->
        [502, %{message: "Camera responded with a Device Busy message.", response: response}]
      {:error, %{reason: :unauthorized, response: response}} ->
        [502, %{message: "Camera responded with a Unauthorized message.", response: response}]
      {:error, %{reason: :forbidden, response: response}} ->
        [502, %{message: "Camera responded with a Forbidden message.", response: response}]
      {:error, %{reason: :not_a_jpeg, response: response}} ->
        [504, %{message: "Camera didn't respond with an image.", response: response}]
      {:error, %HTTPoison.Response{}} ->
        [504, %{message: response.body}]
      {:error, %HTTPoison.Error{id: nil, reason: :timeout}} ->
        [504, %{message: "Camera response timed out."}]
      {:error, %HTTPoison.Error{}} ->
        [504, %{message: "Camera seems to be offline."}]
      {:error, %CaseClauseError{term: {:error, :bad_request}}} ->
        [504, %{message: "Bad request."}]
      _error ->
        [500, %{message: "Sorry, we dropped the ball."}]
    end
  end

  defp get_snapshot(args, retry \\ 1) do
    get_snapshot_response(args, retry)
  end

  defp get_snapshot_response(args, 3) do
    response = CamClient.fetch_snapshot(args)
    parse_camera_response(args, response, args[:store_snapshot])
  end

  defp get_snapshot_response(args, retry) do
    response = CamClient.fetch_snapshot(args)

    case {response, args[:is_online]} do
      {{:error, _error}, true} ->
        get_snapshot(args, retry+1)
      _ ->
        parse_camera_response(args, response, args[:store_snapshot])
    end
  end

  defp parse_camera_response(args, {:ok, data}, true) do
    spawn fn ->
      Logger.debug "Uploading snapshot to S3 for camera #{args[:camera_exid]} taken at #{args[:timestamp]}"
      S3.upload(args[:camera_exid], args[:timestamp], data)
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
    DBHandler.parse_snapshot_error(camera_exid, timestamp, error)
  end
end
