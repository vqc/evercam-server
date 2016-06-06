defmodule EvercamMedia.CameraShareRequestControllerTest do
  use EvercamMedia.ConnCase

  setup do
    country = Repo.insert!(%Country{name: "Something", iso3166_a2: "PK"})
    user = Repo.insert!(%User{firstname: "John", lastname: "Doe", username: "johndoe", email: "john@doe.com", password: "password123", country_id: country.id, api_id: UUID.uuid4(:hex), api_key: UUID.uuid4(:hex)})
    camera = Repo.insert!(%Camera{owner_id: user.id, name: "Austin", exid: "austin", is_public: false, config: ""})
    _share_request = Repo.insert!(%CameraShareRequest{camera_id: camera.id, user_id: user.id, key: UUID.uuid4(:hex), email: "abc@email.com", status: -1, rights: "list,snapshot"})

    {:ok, user: user, camera: camera}
  end

  test "GET /v1/cameras/:id/shares/requests, with valid params", context do
    response =
      build_conn
      |> get("/v1/cameras/austin/shares/requests?api_id=#{context[:user].api_id}&api_key=#{context[:user].api_key}")

    share_requests = List.first(Poison.decode!(response.resp_body)["share_requests"])

    assert response.status() == 200
    assert share_requests["camera_id"] == context[:camera].exid
  end

  test "GET /v1/cameras/:id/shares/requests, when camera does not exist", context do
    response =
      build_conn()
      |> get("/v1/cameras/austinxyz/shares/requests?api_id=#{context[:user].api_id}&api_key=#{context[:user].api_key}")

    assert response.status == 404
    assert Poison.decode!(response.resp_body)["message"] == "The austinxyz camera does not exist."
  end

  test "GET /v1/cameras/:id/shares/requests, when required keys are missing" do
    response =
      build_conn()
      |> get("/v1/cameras/cameraxyz/shares/requests")

    assert response.status == 401
    assert Poison.decode!(response.resp_body)["message"] == "Unauthorized."
  end
end
