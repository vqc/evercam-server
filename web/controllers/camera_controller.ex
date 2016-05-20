defmodule EvercamMedia.CameraController do
  use EvercamMedia.Web, :controller
  alias EvercamMedia.CameraView
  alias EvercamMedia.ErrorView
  alias EvercamMedia.Snapshot.Storage
  alias EvercamMedia.Snapshot.WorkerSupervisor
  alias EvercamMedia.Util
  require Logger
  import String, only: [to_integer: 1]

  def port_check(conn, params) do
    case check_params(params) do
      {:invalid, message} ->
        json(conn, %{error: message})
      :ok ->
        response = %{
          address: params["address"],
          port: to_integer(params["port"]),
          open: Util.port_open?(params["address"], params["port"])
        }
        json(conn, response)
    end
  end

  def index(conn, params) do
    requester = conn.assigns[:current_user]

    if requester do
      requested_user =
        case requester do
          %User{} -> requester
          %AccessToken{} -> User.by_username(params["user_id"])
        end

      include_shared? =
        case params["include_shared"] do
          "false" -> false
          "true" -> true
          _ -> true
        end

      data = ConCache.get_or_store(:cameras, "#{requested_user.username}_#{include_shared?}", fn() ->
        cameras = Camera.for(requested_user, include_shared?)
        Phoenix.View.render(CameraView, "index.json", %{cameras: cameras, user: requester})
      end)

      json(conn, data)
    else
      conn
      |> put_status(404)
      |> render(ErrorView, "error.json", %{message: "Not found."})
    end
  end

  def show(conn, params) do
    current_user = conn.assigns[:current_user]
    camera =
      params["id"]
      |> String.replace_trailing(".json", "")
      |> Camera.get_full

    if Permission.Camera.can_list?(current_user, camera) do
      conn
      |> render("show.json", %{camera: camera, user: current_user})
    else
      conn
      |> put_status(404)
      |> render(ErrorView, "error.json", %{message: "Not found."})
    end
  end

  def thumbnail(conn, %{"id" => exid, "timestamp" => iso_timestamp, "token" => token}) do
    try do
      [token_exid, token_timestamp] = Util.decode(token)
      if exid != token_exid, do: raise "Invalid token."
      if iso_timestamp != token_timestamp, do: raise "Invalid token."

      image = Storage.thumbnail_load(exid)

      conn
      |> put_status(200)
      |> put_resp_header("content-type", "image/jpeg")
      |> text(image)
    rescue
      error ->
        Logger.error "[#{exid}] [thumbnail] [error] [inspect #{error}]"
        send_resp(conn, 500, "Invalid token.")
    end
  end

  def touch(conn, %{"id" => exid, "token" => token}) do
    try do
      [token_exid, _timestamp] = Util.decode(token)
      if exid != token_exid, do: raise "Invalid token."

      Logger.info "Camera update for #{exid}"
      exid |> Camera.get_full |> Camera.invalidate_camera
      camera = exid |> Camera.get_full
      worker = exid |> String.to_atom |> Process.whereis

      case worker do
        nil ->
          WorkerSupervisor.start_worker(camera)
        _ ->
          WorkerSupervisor.update_worker(worker, camera)
      end
      send_resp(conn, 200, "Camera update request received.")
    rescue
      error ->
        Logger.error "Camera update for #{exid} with error: #{inspect error}"
        send_resp(conn, 500, "Invalid token.")
    end
  end

  defp check_params(params) do
    with :ok <- valid?("address", params["address"]),
         :ok <- valid?("port", params["port"]),
         do: :ok
  end

  defp valid?(key, value) when value in [nil, ""],  do: invalid(key)

  defp valid?("address" = key, value) do
    cond do
      :inet_parse.address(String.to_char_list(value)) |> elem(0) == :ok -> :ok
      :inet_parse.domain(String.to_char_list(value)) -> :ok
      true -> invalid(key)
    end
  end

  defp valid?("port" = _key, value) when is_integer(value) and value < 65535, do: :ok
  defp valid?("port" = key, value) when is_binary(value) do
    case Integer.parse(value) do
      {int_value, ""} -> valid?(key, int_value)
      _ -> invalid(key)
    end
  end

  defp valid?("port" = key, _), do: invalid(key)

  defp invalid(key), do: {:invalid, "The parameter '#{key}' isn't valid."}
end
