defmodule EvercamMedia.CameraControllerTest do
  use EvercamMedia.ConnCase
  alias Calendar.DateTime
  alias Calendar.Strftime
  alias EvercamMedia.SnapshotRepo
  alias EvercamMedia.Util
  alias EvercamMedia.Snapshot.Storage

  setup do
    System.put_env("SNAP_KEY", "aaaaaaaaaaaaaaaa")
    System.put_env("SNAP_IV", "bbbbbbbbbbbbbbbb")

    country = Repo.insert!(%Country{name: "Something", iso3166_a2: "SMT"})
    user = Repo.insert!(%User{firstname: "John", lastname: "Doe", username: "johndoe", email: "john@doe.com", password: "password123", country_id: country.id})
    camera = Repo.insert!(%Camera{owner_id: user.id, name: "Austin", exid: "austin", is_public: false, config: ""})

    timestamp = DateTime.now!("UTC") |> DateTime.Format.unix
    datetime = DateTime.now!("UTC") |> Ecto.DateTime.cast!
    snapshot_timestamp = DateTime.now!("UTC") |> Strftime.strftime!("%Y%m%d%H%M%S%f")
    snapshot_id = Util.format_snapshot_id(camera.id, snapshot_timestamp)
    %Snapshot{}
    |> Snapshot.changeset(%{camera_id: camera.id, notes: "", motionlevel: 0, created_at: datetime, snapshot_id: snapshot_id})
    |> SnapshotRepo.insert

    Storage.save(camera.exid, timestamp, "test_content")

    :ok
  end

  test "GET /v1/cameras/:id/thumbnail" do
    camera_exid = "austin"
    iso_timestamp =
      DateTime.now!("UTC")
      |> Strftime.strftime!("%Y-%m-%dT%H:%M:%S.%f")
      |> String.slice(0, 23)
      |> String.ljust(24, ?Z)
    token = Util.encode([camera_exid, iso_timestamp])

    response =
      conn()
      |> get("/v1/cameras/#{camera_exid}/thumbnail/#{iso_timestamp}?token=#{token}")
      |> response(200)

    assert "test_content" == response
  end
end
