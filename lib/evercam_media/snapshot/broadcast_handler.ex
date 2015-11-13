defmodule EvercamMedia.Snapshot.BroadcastHandler do
  use Calendar
  use GenEvent

  @moduledoc """
  TODO
  """

  # def handle_event({:got_snapshot, data}, state) do
  #   timestamp = DateTime.now_utc |> DateTime.Format.unix
  #   {camera_exid, _, image} = data
  #   EvercamMedia.Endpoint.broadcast(
  #     "cameras:#{camera_exid}",
  #     "snapshot-taken",
  #     %{image: Base.encode64(image), timestamp: timestamp}
  #   )
  #   {:ok, state}
  # end

  def handle_event(_, state) do
    {:ok, state}
  end
end
