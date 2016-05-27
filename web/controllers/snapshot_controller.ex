defmodule EvercamMedia.SnapshotController do
  use EvercamMedia.Web, :controller
  use Calendar
  alias EvercamMedia.Snapshot.CamClient
  alias EvercamMedia.Snapshot.DBHandler
  alias EvercamMedia.Snapshot.Error
  alias EvercamMedia.Snapshot.Storage
  alias EvercamMedia.Util

  @optional_params %{"notes" => nil, "with_data" => false}

  def live(conn, %{"id" => camera_exid}) do
    case snapshot_with_user(camera_exid, conn.assigns[:current_user], false) do
      {200, response} ->
        conn
        |> put_status(200)
        |> put_resp_header("content-type", "image/jpeg")
        |> text(response[:image])
      {code, response} ->
        conn
        |> put_status(code)
        |> json(response)
    end
  end

  def create(conn, %{"id" => camera_exid} = params) do
    params = Map.merge(@optional_params, params)
    function = fn -> snapshot_with_user(camera_exid, conn.assigns[:current_user], true, params["notes"]) end
    case {exec_with_timeout(function, 25), params["notes"]} do
      {{200, response}, "true"} ->
        data = "data:image/jpeg;base64,#{Base.encode64(response[:image])}"

        conn
        |> put_status(200)
        |> json(%{created_at: response[:timestamp], notes: response[:notes], data: data})
      {{200, response}, _} ->
        conn
        |> put_status(200)
        |> json(%{created_at: response[:timestamp], notes: response[:notes]})
      {{code, response}, _} ->
        conn
        |> put_status(code)
        |> json(response)
    end
  end

  def test(conn, params) do
    function = fn -> test_snapshot(params) end
    case exec_with_timeout(function, 15) do
      {200, response} ->
        data = "data:image/jpeg;base64,#{Base.encode64(response[:image])}"

        conn
        |> put_status(200)
        |> json(%{data: data, status: "ok"})
      {code, response} ->
        conn
        |> put_status(code)
        |> json(response)
    end
  end

  def thumbnail(conn, %{"id" => camera_exid}) do
    case snapshot_thumbnail(camera_exid, conn.assigns[:current_user]) do
      {200, response} ->
        conn
        |> put_status(200)
        |> put_resp_header("content-type", "image/jpeg")
        |> text(response[:image])
      {code, response} ->
        conn
        |> put_status(code)
        |> put_resp_header("content-type", "image/jpeg")
        |> text(response[:image])
    end
  end

  def data(conn, %{"id" => camera_exid, "snapshot_id" => snapshot_id, "notes" => notes}) do
    case snapshot_data(camera_exid, snapshot_id, notes) do
      {200, response} ->
        conn
        |> put_status(200)
        |> put_resp_header("content-type", "image/jpeg")
        |> text(response)
      {code, _response} ->
        conn
        |> put_status(code)
        |> put_resp_header("content-type", "image/jpeg")
        |> text(Util.storage_unavailable)
    end
  end

  def index(conn, %{"id" => camera_exid, "from" => from, "to" => _to, "limit" => "3600", "page" => _page}) do
    camera = Camera.get_full(camera_exid)
    camera_datetime = camera |> Camera.get_timezone |> DateTime.now!
    offset = camera_datetime.utc_off
    from = convert_to_camera_timestamp(from, offset)

    with true <- Permission.Camera.can_list?(conn.assigns[:current_user], camera),
         true <- Storage.seaweedfs_storage_start_timestmap < from,
         true <- rem(offset, 3600) == 0 do
      Storage.seaweedfs_load_range(camera_exid, from)
    end
    |> case do
         {:ok, snapshots} when snapshots != [] ->
           conn
           |> json(%{snapshots: snapshots})
         _ ->
           conn
           |> proxy_api_data
       end
  end
  def index(conn, _params), do: proxy_api_data(conn)

  def show(conn, %{"id" => camera_exid, "timestamp" => timestamp, "with_data" => "true", "range" => "1"}) do
    timestamp = String.to_integer(timestamp)
    camera = Camera.get_full(camera_exid)
    snapshot_timestamp =
      timestamp
      |> DateTime.Parse.unix!
      |> Strftime.strftime!("%Y%m%d%H%M%S%f")
    snapshot_id = Util.format_snapshot_id(camera.id, snapshot_timestamp)
    snapshot = Snapshot.by_id(snapshot_id)

    with true <- Permission.Camera.can_list?(conn.assigns[:current_user], camera),
         true <- Storage.seaweedfs_storage_start_timestmap < timestamp,
         %Snapshot{notes: notes} <- snapshot do
      Storage.load(camera_exid, snapshot_id, notes)
    end
    |> case do
      {:ok, image} ->
        data = "data:image/jpeg;base64,#{Base.encode64(image)}"
        conn
        |> json(%{snapshots: [%{created_at: timestamp, notes: snapshot.notes, data: data}]})
      _ ->
        conn
        |> proxy_api_data
    end
  end
  def show(conn, _params), do: proxy_api_data(conn)

  ######################
  ## Fetch functions  ##
  ######################

  defp snapshot_with_user(camera_exid, user, store_snapshot, notes \\ "") do
    camera = Camera.get_full(camera_exid)
    if Permission.Camera.can_snapshot?(user, camera) do
      construct_args(camera, store_snapshot, notes) |> fetch_snapshot
    else
      {403, %{message: "Forbidden"}}
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
        handle_camera_response(args, response, args[:store_snapshot])
    end
  end

  defp test_snapshot(params) do
    construct_args(params)
    |> CamClient.fetch_snapshot
    |> handle_test_response
  end

  defp snapshot_data(camera_exid, snapshot_id, notes) do
    case Storage.load(camera_exid, snapshot_id, notes) do
      {:ok, snapshot} ->
        {200, snapshot}
      _ ->
        {404, %{message: "Snapshot not found"}}
    end
  end

  defp snapshot_thumbnail(camera_exid, user) do
    camera = Camera.get_full(camera_exid)
    with true <- Permission.Camera.can_snapshot?(user, camera),
         {:ok, image} <- Storage.thumbnail_load(camera_exid) do
      {:ok, image}
    end
    |> case do
         {:ok, image} -> {200, %{image: image}}
         {:error, error_image} -> {404, %{image: error_image}}
         false -> {403, %{message: "Forbidden"}}
       end
  end

  ####################
  ## Args functions ##
  ####################

  defp construct_args(camera, store_snapshot, notes) do
    %{
      camera_exid: camera.exid,
      is_online: camera.is_online,
      url: Camera.snapshot_url(camera),
      username: Camera.username(camera),
      password: Camera.password(camera),
      vendor_exid: Camera.get_vendor_attr(camera, :exid),
      timestamp: DateTime.Format.unix(DateTime.now_utc),
      store_snapshot: store_snapshot,
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

  #######################
  ## Handler functions ##
  #######################

  defp handle_camera_response(args, {:ok, data}, true) do
    spawn fn ->
      Util.broadcast_snapshot(args[:camera_exid], data, args[:timestamp])
      Storage.save(args[:camera_exid], args[:timestamp], data, args[:notes])
      Storage.seaweedfs_save(args[:camera_exid], args[:timestamp], data, args[:notes])
      DBHandler.update_camera_status(args[:camera_exid], args[:timestamp], true)
      |> DBHandler.save_snapshot_record(args[:timestamp], nil, args[:notes])
    end
    {200, %{image: data, timestamp: args[:timestamp], notes: args[:notes]}}
  end

  defp handle_camera_response(args, {:ok, data}, false) do
    spawn fn ->
      Util.broadcast_snapshot(args[:camera_exid], data, args[:timestamp])
      DBHandler.update_camera_status(args[:camera_exid], args[:timestamp], true)
    end
    {200, %{image: data}}
  end

  defp handle_camera_response(args, {:error, error}, _store_snapshot) do
    Error.parse(error) |> Error.handle(args[:camera_exid], args[:timestamp], error)
  end

  defp handle_test_response({:ok, data}) do
    {200, %{image: data}}
  end

  defp handle_test_response({:error, error}) do
    Error.parse(error) |> Error.handle("", nil, error)
  end

  #######################
  ## Utility functions ##
  #######################

  def exec_with_timeout(function, timeout \\ 5) do
    try do
      Task.async(fn() -> function.() end)
      |> Task.await(:timer.seconds(timeout))
    catch _type, error ->
        Util.error_handler(error)
      {504, %{message: "Request timed out."}}
    end
  end

  defp proxy_api_data(conn) do
    url = "https://api.evercam.io#{conn.request_path}?#{conn.query_string}"

    case HTTPoison.get(url, [], [recv_timeout: 25000]) do
      {:ok, %HTTPoison.Response{body: body}} ->
        {:ok, data} = Poison.decode(body)
        conn
        |> json(data)
      {:error, %HTTPoison.Error{}} ->
        conn
        |> put_status(500)
        |> json(%{message: "Sorry, we dropped the ball."})
    end
  end

  defp convert_to_camera_timestamp(timestamp, offset) do
    timestamp
    |> String.to_integer
    |> DateTime.Parse.unix!
    |> DateTime.advance!(-offset)
    |> DateTime.Format.unix
  end
end
