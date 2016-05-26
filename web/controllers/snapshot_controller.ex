defmodule EvercamMedia.SnapshotController do
  use EvercamMedia.Web, :controller
  use Calendar
  alias EvercamMedia.Snapshot.CamClient
  alias EvercamMedia.Snapshot.DBHandler
  alias EvercamMedia.Snapshot.Error
  alias EvercamMedia.Snapshot.Storage
  alias EvercamMedia.Util

  @optional_params %{"notes" => nil, "with_data" => false}

  def show(conn, %{"id" => camera_exid}) do
    function = fn -> snapshot_with_user(camera_exid, conn.assigns[:current_user], false) end
    [code, response] = Util.exec_with_timeout(function, 15)
    show_render(conn, code, response)
  end

  def create(conn, %{"id" => camera_exid} = params) do
    params = Map.merge(@optional_params, params)
    function = fn -> snapshot_with_user(camera_exid, conn.assigns[:current_user], true, params["notes"]) end
    [code, response] = Util.exec_with_timeout(function, 25)
    create_render(conn, code, response, params["with_data"])
  end

  def test(conn, params) do
    function = fn -> test_snapshot(params) end
    [code, response] = Util.exec_with_timeout(function, 15)
    test_render(conn, code, response)
  end

  def data(conn, %{"id" => camera_exid, "snapshot_id" => snapshot_id, "notes" => notes}) do
    function = fn -> snapshot_data(camera_exid, snapshot_id, notes) end
    [code, response] = Util.exec_with_timeout(function)
    data_render(conn, code, response)
  end

  def thumbnail(conn, %{"id" => camera_exid}) do
    function = fn -> snapshot_thumbnail(camera_exid, conn.assigns[:current_user]) end
    [code, response] = Util.exec_with_timeout(function, 15)
    thumbnail_render(conn, code, response)
  end

  ######################
  ## Render functions ##
  ######################

  defp show_render(conn, 200, response) do
    conn
    |> put_status(200)
    |> put_resp_header("content-type", "image/jpeg")
    |> text(response[:image])
  end

  defp show_render(conn, code, response) do
    conn
    |> put_status(code)
    |> json(response)
  end

  defp create_render(conn, 200, response, "true") do
    data = "data:image/jpeg;base64,#{Base.encode64(response[:image])}"

    conn
    |> put_status(200)
    |> json(%{created_at: response[:timestamp], notes: response[:notes], data: data})
  end

  defp create_render(conn, 200, response, _) do
    conn
    |> put_status(200)
    |> json(%{created_at: response[:timestamp], notes: response[:notes]})
  end

  defp create_render(conn, code, response, _) do
    conn
    |> put_status(code)
    |> json(response)
  end

  defp test_render(conn, 200, response) do
    data = "data:image/jpeg;base64,#{Base.encode64(response[:image])}"

    conn
    |> put_status(200)
    |> json(%{data: data, status: "ok"})
  end

  defp test_render(conn, code, response) do
    conn
    |> put_status(code)
    |> json(response)
  end

  defp data_render(conn, 200, response) do
    conn
    |> put_status(200)
    |> put_resp_header("content-type", "image/jpeg")
    |> text(response)
  end

  defp data_render(conn, code, _response) do
    image = Util.storage_unavailable
    conn
    |> put_status(code)
    |> put_resp_header("content-type", "image/jpeg")
    |> text(image)
  end

  defp thumbnail_render(conn, 200, response) do
    conn
    |> put_status(200)
    |> put_resp_header("content-type", "image/jpeg")
    |> text(response[:image])
  end

  defp thumbnail_render(conn, code, _response) do
    image = Util.unavailable
    conn
    |> put_status(code)
    |> put_resp_header("content-type", "image/jpeg")
    |> text(image)
  end

  ######################
  ## Fetch functions ##
  ######################

  defp snapshot_with_user(camera_exid, user, store_snapshot, notes \\ "") do
    camera = Camera.get_full(camera_exid)
    if Permission.Camera.can_snapshot?(user, camera) do
      construct_args(camera, store_snapshot, notes) |> fetch_snapshot
    else
      [403, %{message: "Forbidden"}]
    end
  end

  defp fetch_snapshot(args, attempt \\ 1) do
    response = CamClient.fetch_snapshot(args)
    timestamp = DateTime.Format.unix(DateTime.now_utc)
    args = Map.put(args, :timestamp, timestamp)

    case {response, args[:is_online], attempt} do
      {{:error, _error}, true, attempt} when attempt <= 3 ->
        fetch_snapshot(args, attempt + 1)
      _ ->
        parse_camera_response(args, response, args[:store_snapshot])
    end
  end

  defp test_snapshot(params) do
    construct_args(params)
    |> CamClient.fetch_snapshot
    |> parse_test_response
  end

  defp snapshot_data(camera_exid, snapshot_id, notes) do
    case Storage.exists?(camera_exid, snapshot_id, notes) do
      false ->
        [404, %{message: "Snapshot not found"}]
      _ ->
        [200, Storage.load(camera_exid, snapshot_id, notes)]
    end
  end

  defp snapshot_thumbnail(camera_exid, user) do
    camera = Camera.get_full(camera_exid)
    thumbnail_exists? = Storage.thumbnail_exists?(camera_exid)
    cond do
      Permission.Camera.can_snapshot?(user, camera) == false ->
        [403, %{message: "Forbidden"}]
      thumbnail_exists? ->
        [200, %{image: Storage.thumbnail_load(camera_exid)}]
      true ->
        [404, %{message: "Snapshot not found"}]
    end
  end

  ####################
  ## Args functions ##
  ####################

  defp construct_args(camera, store_snapshot, notes) do
    timestamp = DateTime.Format.unix(DateTime.now_utc)

    %{
      camera_exid: camera.exid,
      is_online: camera.is_online,
      vendor_exid: Camera.get_vendor_attr(camera, :exid),
      url: Camera.snapshot_url(camera),
      username: Camera.username(camera),
      password: Camera.password(camera),
      store_snapshot: store_snapshot,
      timestamp: timestamp,
      notes: notes
    }
  end

  defp construct_args(params) do
    %{
      vendor_exid: params["vendor_id"],
      url: "#{params["external_url"]}/#{params["jpg_url"]}",
      username: params["cam_username"],
      password: params["cam_password"]
    }
  end

  #####################
  ## Parse functions ##
  #####################

  defp parse_camera_response(args, {:ok, data}, true) do
    spawn fn ->
      Util.broadcast_snapshot(args[:camera_exid], data, args[:timestamp])
      Storage.save(args[:camera_exid], args[:timestamp], data, args[:notes])
      Storage.seaweedfs_save(args[:camera_exid], args[:timestamp], data, args[:notes])
      DBHandler.update_camera_status(args[:camera_exid], args[:timestamp], true)
      |> DBHandler.save_snapshot_record(args[:timestamp], nil, args[:notes])
    end
    [200, %{image: data, timestamp: args[:timestamp], notes: args[:notes]}]
  end

  defp parse_camera_response(args, {:ok, data}, false) do
    spawn fn ->
      Util.broadcast_snapshot(args[:camera_exid], data, args[:timestamp])
      DBHandler.update_camera_status(args[:camera_exid], args[:timestamp], true)
    end
    [200, %{image: data}]
  end

  defp parse_camera_response(args, {:error, error}, _store_snapshot) do
    Error.parse(error) |> Error.handle(args[:camera_exid], args[:timestamp], error)
  end

  defp parse_test_response({:ok, data}) do
    [200, %{image: data}]
  end

  defp parse_test_response({:error, error}) do
    Error.parse(error) |> Error.handle("", nil, error)
  end
end
