defmodule EvercamMedia.Snapshot.PollHandler do
  @moduledoc """
  TODO
  """
  
  use GenEvent

  def handle_event({:update_camera_config, worker_state}, state) do
    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end

end
