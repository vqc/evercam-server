defmodule EvercamMedia.Snapshot.Cleanup do
  alias EvercamMedia.Repo
  alias EvercamMedia.SnapshotRepo
  alias EvercamMedia.Snapshot.S3
  require Logger

  def init do
    CloudRecording.get_all
    |> Enum.map(&run(&1))
  end

  def run(cloud_recording) do
    cloud_recording
    |> Snapshot.expired
    |> Enum.map(&delete(&1, cloud_recording.camera.exid))
  end

  def delete(snapshot, camera_exid) do
    Logger.info "snapshot #{snapshot.snapshot_id} was deleted"

    S3.delete(snapshot, camera_exid)
    SnapshotRepo.delete(snapshot)
  end
end
