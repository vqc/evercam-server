defmodule EvercamMedia.Snapshot.StreamerSupervisor do
  @moduledoc """
  TODO
  """

  use Supervisor
  require Logger

  def start_link() do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [worker(EvercamMedia.Snapshot.Streamer, [], restart: :permanent)]
    supervise(children, strategy: :simple_one_for_one, max_restarts: 1_000_000)
  end

  @doc """
  Start
  """
  def start_streamer(camera_exid) do
    streamer_id = String.to_atom("#{camera_exid}_streamer")
    streamer = Process.whereis(streamer_id)
    case streamer do
      nil ->
        Logger.debug "[#{camera_exid}] Starting streamer"
        camera = EvercamMedia.Repo.one! Camera.by_exid_with_vendor(camera_exid)
        Supervisor.start_child(__MODULE__, [camera])
      is_pid ->
        Logger.debug "[#{camera_exid}] Skipping streamer ..."
    end
  end

  @doc """
  Stop
  """
  def stop_streamer(camera_exid) do
    streamer_id = String.to_atom("#{camera_exid}_streamer")
    Supervisor.terminate_child(__MODULE__, Process.whereis(streamer_id))
  end
end
