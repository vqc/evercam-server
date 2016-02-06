defmodule EvercamMedia.Snapshot.S3UploadHandler do
  @moduledoc """
  TODO
  """

  use GenEvent
  alias EvercamMedia.Snapshot.S3
  alias EvercamMedia.Snapshot.Storage
  require Logger

  def handle_event({:got_snapshot, data}, state) do
    {camera_exid, timestamp, image} = data
    spawn fn ->
      S3.upload(camera_exid, timestamp, image)
    end
    spawn fn ->
      Storage.upload(camera_exid, timestamp, image)
    end
    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end
end
