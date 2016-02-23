defmodule EvercamMedia.Snapshot.Cleanup do
  alias EvercamMedia.Snapshot.S3
  alias EvercamMedia.Snapshot.Storage
  alias EvercamMedia.Util
  require Logger

  def init do
    CloudRecording.get_all_ephemeral
    |> Enum.map(&run(&1))
  end

  def run(cloud_recording) do
    cloud_recording
    |> Storage.cleanup

    cloud_recording
    |> Snapshot.expired
    |> prepare_lists
    |> cleanup(cloud_recording.camera)
  end

  def cleanup(list, camera) do
    Enum.each(list, fn(pair) ->
      delete(camera, pair)
    end)
  end

  def delete(camera, {range, prefix_list}) do
    Logger.info "[#{camera.exid}] [snapshot_delete_db] [#{inspect range}]"
    S3.delete(camera.exid, prefix_list)
    Snapshot.delete_by_range(camera.id, range)
  end

  defp prepare_lists([[], []]), do: []
  defp prepare_lists(ranges) do
    s3_prefixes = ranges |> convert_timestamps |> construct_prefix_lists
    Enum.zip(ranges, s3_prefixes)
  end

  defp convert_timestamps(ranges) do
    Enum.map(ranges, fn(chunk) ->
      Enum.map(chunk, fn(timestamp) ->
        Util.snapshot_timestamp_to_unix(timestamp)
      end)
    end)
  end

  defp construct_prefix_lists(ranges) do
    Enum.map(ranges, fn([first, last]) ->
      S3.list_prefixes(first, last)
    end)
  end
end
