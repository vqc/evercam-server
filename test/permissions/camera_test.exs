defmodule Permissions.CameraTest do
  use EvercamMedia.ModelCase

  setup do
    ConCache.delete(:camera, "123")
    :ok
  end

  test "owner can do anything to the camera" do
    country = Repo.insert!(%Country{name: "Something", iso3166_a2: "SMT"})
    user = Repo.insert!(%User{firstname: "John", lastname: "Doe", username: "johndoe", email: "john@doe.com", password: "password123", country_id: country.id})
    token = Repo.insert!(%AccessToken{user_id: user.id, is_revoked: false, request: "whatever", expires_at: Ecto.DateTime.from_erl({{2020,01,01}, {10,10,10}})})
    camera = Repo.insert!(%Camera{owner_id: user.id, name: "camera 1", exid: "123", is_public: false, config: ""})
    _access_right = Repo.insert!(%AccessRight{token_id: token.id, right: "edit", camera_id: camera.id, status: 1, scope: "cameras"})

    assert Permissions.Camera.can_edit?(user, camera.exid)
    assert Permissions.Camera.can_view?(user, camera.exid)
    assert Permissions.Camera.can_snapshot?(user, camera.exid)
    assert Permissions.Camera.can_delete?(user, camera.exid)
    assert Permissions.Camera.can_list?(user, camera.exid)
    assert Permissions.Camera.can_grant?(user, camera.exid)
  end

  test ".can_edit(user, camera) - returns false if the USER cannot EDIT the CAMERA" do
    country = Repo.insert!(%Country{name: "Something", iso3166_a2: "SMT"})
    user = Repo.insert!(%User{firstname: "John", lastname: "Doe", username: "johndoe", email: "john@doe.com", password: "password123", country_id: country.id})
    owner = Repo.insert!(%User{firstname: "Jane", lastname: "Doe", username: "janedoe", email: "jane@doe.net", password: "password123", country_id: country.id})
    token = Repo.insert!(%AccessToken{user_id: user.id, is_revoked: false, request: "whatever", expires_at: Ecto.DateTime.from_erl({{2020,01,01}, {10,10,10}})})
    camera = Repo.insert!(%Camera{owner_id: owner.id, name: "camera 1", exid: "123", is_public: false, config: ""})
    _access_right = Repo.insert!(%AccessRight{token_id: token.id, right: "view", camera_id: camera.id, status: 1, scope: "cameras"})

    assert Permissions.Camera.can_view?(user, camera.exid)
    refute Permissions.Camera.can_edit?(user, camera.exid)
  end

  test ".can_edit(user, camera) - returns true if the USER can EDIT the CAMERA" do
    country = Repo.insert!(%Country{name: "Something", iso3166_a2: "SMT"})
    user = Repo.insert!(%User{firstname: "John", lastname: "Doe", username: "johndoe", email: "john@doe.com", password: "password123", country_id: country.id})
    owner = Repo.insert!(%User{firstname: "Jane", lastname: "Doe", username: "janedoe", email: "jane@doe.net", password: "password123", country_id: country.id})
    token = Repo.insert!(%AccessToken{user_id: user.id, is_revoked: false, request: "whatever", expires_at: Ecto.DateTime.from_erl({{2020,01,01}, {10,10,10}})})
    camera = Repo.insert!(%Camera{owner_id: owner.id, name: "camera 1", exid: "123", is_public: false, config: ""})
    _access_right = Repo.insert!(%AccessRight{token_id: token.id, right: "edit", camera_id: camera.id, status: 1, scope: "cameras"})

    assert Permissions.Camera.can_edit?(user, camera.exid)
  end

  test ".can_edit(user, camera) - returns false if USER has other access rights but not EDIT" do
    country = Repo.insert!(%Country{name: "Something", iso3166_a2: "SMT"})
    user = Repo.insert!(%User{firstname: "John", lastname: "Doe", username: "johndoe", email: "john@doe.com", password: "password123", country_id: country.id})
    owner = Repo.insert!(%User{firstname: "Jane", lastname: "Doe", username: "janedoe", email: "jane@doe.net", password: "password123", country_id: country.id})
    token = Repo.insert!(%AccessToken{user_id: user.id, is_revoked: false, request: "whatever", expires_at: Ecto.DateTime.from_erl({{2020,01,01}, {10,10,10}})})
    camera = Repo.insert!(%Camera{owner_id: owner.id, name: "camera 1", exid: "123", is_public: false, config: ""})
    _grant_right = Repo.insert!(%AccessRight{token_id: token.id, right: "grant", camera_id: camera.id, status: 1, scope: "cameras"})
    _view_right = Repo.insert!(%AccessRight{token_id: token.id, right: "list", camera_id: camera.id, status: 1, scope: "cameras"})

    assert Permissions.Camera.can_list?(user, camera.exid)
    assert Permissions.Camera.can_grant?(user, camera.exid)
    refute Permissions.Camera.can_edit?(user, camera.exid)
  end
end
