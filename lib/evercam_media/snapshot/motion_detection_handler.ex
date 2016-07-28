defmodule EvercamMedia.Snapshot.MotionDetectionHandler do
  use GenEvent
  alias EvercamMedia.Snapshot.MotionDetection
  alias EvercamMedia.Snapshot.Storage

  @moduledoc """
  Runs motion detection on the current and last cached snapshot.
  """

  def handle_event({:got_snapshot, data}, state) do
    {camera_exid, timestamp, image} = data
    cached_image = ConCache.get(:cache, camera_exid)
    motion_level = calculate_motion_level(camera_exid, image, cached_image)
    ConCache.put(:cache, camera_exid, image)
    Storage.motion_level_save(camera_exid, timestamp, "Evercam Proxy", motion_level)
    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end

  def calculate_motion_level(_camera_exid, _image_1, nil), do: nil
  def calculate_motion_level(camera_exid, image_1, image_2) do
    MotionDetection.compare(camera_exid, image_1, image_2)
  end
end
