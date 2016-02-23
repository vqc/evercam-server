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
      Storage.save(camera_exid, timestamp, image, "Evercam Proxy")
    end
    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end
end
