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
  Start streamer process
  """
  def start_streamer(camera_exid) do
    case find_streamer(camera_exid) do
      nil ->
        Logger.debug "[#{camera_exid}] Starting streamer"
        Supervisor.start_child(__MODULE__, [camera_exid])
      is_pid ->
        Logger.debug "[#{camera_exid}] Skipping streamer ..."
    end
  end

  @doc """
  Stop streamer process
  """
  def stop_streamer(camera_exid) do
    streamer_id = String.to_atom("#{camera_exid}_streamer")
    Supervisor.terminate_child(__MODULE__, Process.whereis(streamer_id))
  end

  @doc """
  Find streamer process
  """
  def find_streamer(camera_exid) do
    "#{camera_exid}_streamer"
    |> String.to_atom
    |> Process.whereis
  end
end
