defmodule EvercamMedia.Snapshot.Cleanup do
  alias EvercamMedia.Repo
  alias EvercamMedia.SnapshotRepo
  alias EvercamMedia.Snapshot.S3
  require Logger

  def init do
    CloudRecording.get_all
    |> Enum.map(fn(cl) -> run(cl) end)
  end

  def run(cloud_recording) do
    cloud_recording
    |> Snapshot.expired
    |> Enum.map(fn(snap) -> delete(snap, cloud_recording.camera.exid) end)
  end

  def delete(snapshot, camera_exid) do
    Logger.info "snapshot #{snapshot.snapshot_id} would be deleted"

    # S3.delete snapshot, camera_exid
    # SnapshotRepo.delete snapshot
  end
end
