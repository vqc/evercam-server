defmodule EvercamMedia.Timelapse.StorageHandler do
  @moduledoc """
  Provides functions to save snapshot captured for timelapse
  """

  use GenEvent
  alias EvercamMedia.Snapshot.Storage

  def handle_event({:got_snapshot, data}, state) do
    {camera_exid, timestamp, image} = data
    spawn fn -> Storage.save(camera_exid, timestamp, image, "Evercam Timelapse") end
    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end
end
