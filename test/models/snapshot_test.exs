defmodule SnapshotTest do
  use EvercamMedia.ModelCase
  alias EvercamMedia.Util

  setup do
    country = Repo.insert!(
      %Country{
        name: "Aruba",
        iso3166_a2: "whatever"})
    user = Repo.insert!(
      %User{
        firstname: "John",
        lastname: "Doe",
        email: "johndoe@example.com",
        password: "something",
        username: "jdoe123",
        country_id: country.id})
    camera = Repo.insert!(
      %Camera{
        exid: "my_camera",
        name: "My Camera",
        owner_id: user.id,
        is_public: false,
        config: %{},
        is_online_email_owner_notification: false})
    cloud_recording = Repo.insert!(
      %CloudRecording{
        camera_id: camera.id,
        frequency: 1,
        storage_duration: 7,
        schedule: %{
          "Monday" => ["00:00-23:59"],
          "Tuesday" => ["00:00-23:59"],
          "Wednesday" => ["00:00-23:59"],
          "Thursday" => ["00:00-23:59"],
          "Friday" => ["00:00-23:59"],
          "Saturday" => ["00:00-23:59"],
          "Sunday" => ["00:00-23:59"]}})
    SnapshotRepo.insert!(
      %Snapshot{
        camera_id: camera.id,
        snapshot_id: Util.format_snapshot_id(camera.id, "2016011902242662241"),
        notes: "Evercam Proxy"})
    SnapshotRepo.insert!(
      %Snapshot{
        camera_id: camera.id,
        snapshot_id: Util.format_snapshot_id(camera.id, "2016011903310662241"),
        notes: "Evercam Proxy"})
    SnapshotRepo.insert!(
      %Snapshot{
        camera_id: camera.id,
        snapshot_id: Util.format_snapshot_id(camera.id, "2016011903474662241"),
        notes: "Custom Note"})

    {:ok, cloud_recording: Repo.preload(cloud_recording, :camera)}
  end

  test "lists ranges of expired snapshots", %{cloud_recording: cloud_recording} do
    ranges = [["20160119000000", "20160119034746622"], ["20160119034746622", "20160120000000"]]
    assert Snapshot.expired(cloud_recording) == ranges
  end
end
