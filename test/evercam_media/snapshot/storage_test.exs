defmodule EvercamMedia.Snapshot.StorageTest do
  use ExUnit.Case, async: true
  alias EvercamMedia.Snapshot.Storage

  test "construct_file_path/2 converts the file path correctly" do
    camera_exid = "austin"
    timestamp = 1454715880
    file_path = "snapshots/austin/recordings/2016/02/05/23/44/40.jpg"

    assert Storage.construct_file_path(camera_exid, timestamp) == file_path
  end
end
