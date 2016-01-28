defmodule SnapshotTest do
  use EvercamMedia.ModelCase
  alias EvercamMedia.Util
  alias Calendar.Date
  alias Calendar.DateTime
  alias Calendar.Strftime
  alias Calendar.NaiveDateTime
  setup do
    seconds_to_8_days_ago = (8) * (24 * 60 * 60) * (-1)
    expiry_day =
      DateTime.now_utc
      |> DateTime.advance!(seconds_to_8_days_ago)
      |> Strftime.strftime!("%Y%m%d")

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
        config: %{}})
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
        snapshot_id: Util.format_snapshot_id(camera.id, "#{expiry_day}02242662241"),
        notes: "Evercam Proxy"})
    SnapshotRepo.insert!(
      %Snapshot{
        camera_id: camera.id,
        snapshot_id: Util.format_snapshot_id(camera.id, "#{expiry_day}03310662241"),
        notes: "Evercam Proxy"})
    SnapshotRepo.insert!(
      %Snapshot{
        camera_id: camera.id,
        snapshot_id: Util.format_snapshot_id(camera.id, "#{expiry_day}03474662241"),
        notes: "Custom Note"})

    {:ok, cloud_recording: Repo.preload(cloud_recording, :camera), expiry_day: expiry_day}
  end

  test "lists ranges of expired snapshots", %{cloud_recording: cloud_recording, expiry_day: expiry_day} do
    {:ok, timestamp, _} = NaiveDateTime.Parse.asn1_generalized("#{expiry_day}000000")
    end_day = timestamp |> Date.next_day! |> Strftime.strftime!("%Y%m%d")
    ranges = [["#{expiry_day}000000", "#{expiry_day}034746622"], ["#{expiry_day}034746622", "#{end_day}000000"]]
    assert Snapshot.expired(cloud_recording) == ranges
  end
end
