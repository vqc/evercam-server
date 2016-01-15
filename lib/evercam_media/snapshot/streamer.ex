defmodule EvercamMedia.Snapshot.Streamer do
  @moduledoc """
  TODO
  """

  use Calendar
  use GenServer
  alias EvercamMedia.Util
  alias EvercamMedia.Snapshot.CamClient
  alias EvercamMedia.Snapshot.DBHandler
  import EvercamMedia.Schedule
  import Camera

  ################
  ## Client API ##
  ################

  @doc """
  Start the Snapshot streamer for a given camera.
  """
  def start_link(camera) do
    streamer_id = String.to_atom("#{camera.exid}_streamer")
    GenServer.start_link(__MODULE__, camera, name: streamer_id)
  end

  ######################
  ## Server Callbacks ##
  ######################

  @doc """
  Initialize the camera streamer
  """
  def init(args) do
    Task.start_link(fn -> loop(args) end)
    {:ok, args}
  end

  def loop(camera) do
    streamer_id = String.to_atom("#{camera.exid}_streamer")
    subscribers = Phoenix.PubSub.Local.subscribers(EvercamMedia.PubSub, "cameras:#{camera.exid}", 0)

    cond do
      length(subscribers) == 0 ->
        Supervisor.terminate_child(EvercamMedia.Snapshot.StreamerSupervisor, Process.whereis(streamer_id))
      camera.cloud_recordings == nil ->
        spawn fn -> stream(camera) end
      scheduled_now?(camera.cloud_recordings.schedule, camera.timezone) && sleep(camera.cloud_recordings) == 1000 ->
        Supervisor.terminate_child(EvercamMedia.Snapshot.StreamerSupervisor, Process.whereis(streamer_id))
      true ->
        spawn fn -> stream(camera) end
    end

    :timer.sleep 1000
    loop(camera)
  end

  def stream(camera) do
    timestamp = DateTime.now_utc |> DateTime.Format.unix

    args = %{
      url: Camera.snapshot_url(camera),
      vendor_exid: Camera.vendor_exid(camera),
      username: Camera.username(camera),
      password: Camera.password(camera)
    }

    response = CamClient.fetch_snapshot(args)

    case response do
      {:ok, data} ->
        Util.broadcast_snapshot(camera.exid, data, timestamp)
      {:error, error} ->
        DBHandler.parse_snapshot_error(camera.exid, timestamp, error)
    end
  end
end
