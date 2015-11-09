defmodule EvercamMedia.Snapshot.BroadcastHandler do
  use GenEvent

  @moduledoc """
  TODO
  """

  def handle_event({:got_snapshot, data}, state) do
    {camera_exid, timestamp, image} = data
    EvercamMedia.Endpoint.broadcast(
      "cameras:#{camera_exid}",
      "snapshot-taken",
      %{image: Base.encode64(image), timestamp: timestamp}
    )
    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end

end
