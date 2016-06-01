defmodule EvercamMedia.CameraShareControllerTest do
  use EvercamMedia.ConnCase

  setup do
    country = Repo.insert!(%Country{name: "Something", iso3166_a2: "PK"})
    user = Repo.insert!(%User{firstname: "John", lastname: "Doe", username: "johndoe", email: "john@doe.com", password: "password123",
      country_id: country.id, api_id: UUID.uuid4(:hex), api_key: UUID.uuid4(:hex)})
    user2 = Repo.insert!(%User{firstname: "Smith", lastname: "Marc", username: "smithmarc", email: "smith@dmarc.com", password: "password456",
      country_id: country.id, api_id: UUID.uuid4(:hex), api_key: UUID.uuid4(:hex)})
    camera = Repo.insert!(%Camera{owner_id: user.id, name: "Austin", exid: "austin", is_public: false, config: ""})
    share = Repo.insert!(%CameraShare{camera_id: camera.id, user_id: user2.id, sharer_id: user.id, kind: "private"})

    {:ok, user: user, camera: camera, share: share}
  end

  test "GET /v1/cameras/:id/shares, with valid params", context do
    response =
      build_conn
      |> get("/v1/cameras/austin/shares?api_id=#{context[:user].api_id}&api_key=#{context[:user].api_key}")

    shares =
      response.resp_body
      |> Poison.decode!
      |> Map.get("shares")
      |> List.first

    assert response.status() == 200
    assert shares["camera_id"] == context[:camera].exid
  end

  test "GET /v1/cameras/:id/shares, when passed user_id not exist", context do
    response =
      build_conn()
      |> get("/v1/cameras/austin/shares?user_id=johndoexyz&api_id=#{context[:user].api_id}&api_key=#{context[:user].api_key}")

    assert response.status == 404
    assert Poison.decode!(response.resp_body)["message"] == "User 'johndoexyz' does not exist."
  end

  test "GET /v1/cameras/:id/shares, when camera does not exist", context do
    response =
      build_conn()
      |> get("/v1/cameras/austinxyz/shares?api_id=#{context[:user].api_id}&api_key=#{context[:user].api_key}")

    assert response.status == 404
    assert Poison.decode!(response.resp_body)["message"] == "The austinxyz camera does not exist."
  end

  test "GET /v1/cameras/:id/shares, when required keys are missing" do
    response =
      build_conn()
      |> get("/v1/cameras/austin/shares")

    assert response.status == 401
    assert Poison.decode!(response.resp_body)["message"] == "Unauthorized."
  end
end
