defmodule EvercamMedia.Timelapse.PollHandler do
  @moduledoc """
  Provide functions to update timelapse worker config
  """
  alias EvercamMedia.Timelapse.Poller

  use GenEvent

  def handle_event({:update_timelapse_config, worker_state}, state) do
    Poller.update_config(worker_state.poller, worker_state)
    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end
end
