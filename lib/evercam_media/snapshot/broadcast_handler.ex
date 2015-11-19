defmodule EvercamMedia.Snapshot.BroadcastHandler do
  use Calendar
  use GenEvent
  alias EvercamMedia.Util


  @moduledoc """
  TODO
  """

  def handle_event({:got_snapshot, data}, state) do
    {camera_exid, timestamp, image} = data
    Util.broadcast_snapshot(camera_exid, image, timestamp)    
    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end
end
