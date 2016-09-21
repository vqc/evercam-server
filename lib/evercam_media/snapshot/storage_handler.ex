defmodule EvercamMedia.Snapshot.StorageHandler do
  @moduledoc """
  TODO
  """

  use GenEvent
  alias EvercamMedia.Snapshot.Storage
  require Logger

  def handle_event({:got_snapshot, data}, state) do
    {camera_exid, timestamp, image} = data
    spawn fn ->
      last_image = ConCache.get(:last_snapshot, camera_exid)
      with true <- last_image != image do
        Storage.save(camera_exid, timestamp, image, "Evercam Proxy")
      else
        false -> Logger.info "[#{camera_exid}] [save_image] [duplicate_image]"
      end
      ConCache.put(:last_snapshot, camera_exid, image)
    end
    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end
end
