defmodule EvercamMedia.Snapshot.PollHandler do
  @moduledoc """
  TODO
  """
  alias EvercamMedia.Snapshot.Poller

  use GenEvent

  def handle_event({:update_camera_config, worker_state}, state) do
    Poller.update_config(worker_state.poller, worker_state)
    {:ok, state}
  end

  def handle_event({:wait_and_send_request, worker_state, seconds}, state) do
    Poller.wait_send_request(worker_state.poller, worker_state, seconds)
    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end
end
