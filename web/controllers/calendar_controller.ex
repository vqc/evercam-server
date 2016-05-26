defmodule EvercamMedia.CalendarController do
  use EvercamMedia.Web, :controller
  use Calendar
  alias EvercamMedia.Snapshot.Storage

  def index(conn, %{"id" => camera_exid, "from" => from, "to" => _to, "limit" => "3600", "page" => _page}) do
    seaweedfs_storage_start_timestmap = 1463788800
    camera = Camera.get_full(camera_exid)
    camera_datetime = camera |> Camera.get_timezone |> DateTime.now!
    offset = camera_datetime.std_off
    from = convert_to_camera_timestamp(from, offset)

    with true <- Permission.Camera.can_list?(conn.assigns[:current_user], camera),
         true <- seaweedfs_storage_start_timestmap < from,
         true <- rem(offset, 3600) == 0 do
      Storage.seaweedfs_load_range(camera_exid, from)
    end
    |> case do
      {:ok, snapshots} ->
        conn
        |> json(%{snapshots: snapshots})
      _ ->
        conn
        |> proxy_api_data
    end
  end

  def index(conn, _params) do
    proxy_api_data(conn)
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
