defmodule EvercamMedia.UserSignupTest do
  use EvercamMedia.ModelCase
  alias EvercamMedia.UserSignup

  test ".create - returns :invalid_user when changeset is invalid" do
    changeset = User.changeset(%User{})

    assert UserSignup.create(changeset) == { :invalid_user, changeset }
  end

  test ".create - returns :duplicate_user when user creation fails" do
    { :ok, country } = EvercamMedia.Repo.insert(%Country{ name: "Some Country", iso3166_a2: "SC" })

    user_params = %{ firstname: "John",
      lastname: "Doe", email: "jdoe@example.net", password: "password123",
      country_id: country.id, username: "jdoe123" }

    valid_changeset = User.changeset(%User{}, user_params)
    { :ok, _user } = EvercamMedia.Repo.insert(valid_changeset)

    duplicate_changeset = User.changeset(%User{}, user_params)

    assert match?({ :duplicate_user, _ }, UserSignup.create(duplicate_changeset))
  end

  @tag :skip
  test ".create - returns :invalid_token if it cannot save the user access token" do
    { :ok, country } = EvercamMedia.Repo.insert(%Country{ name: "Some Country", iso3166_a2: "SC" })

    user_params = %{ firstname: "John",
      lastname: "Doe", email: "jdoe@example.net", password: "password123",
      country_id: country.id, username: "jdoe123" }

    valid_changeset = User.changeset(%User{}, user_params)
    { :ok, _user } = EvercamMedia.Repo.insert(valid_changeset)

    duplicate_changeset = User.changeset(%User{}, user_params)

    assert match?({ :invalid_token, _ }, UserSignup.create(duplicate_changeset))
  end

  test ".create - returns :success if the signup was successfull" do
    { :ok, country } = EvercamMedia.Repo.insert(%Country{ name: "Some Country", iso3166_a2: "SC" })

    user_params = %{ firstname: "John", lastname: "Doe", email: "jdoe@example.net",
      password: "password123", country_id: country.id, username: "jdoe123" }

    valid_changeset = User.changeset(%User{}, user_params)

    assert match?({ :success, _, _ }, UserSignup.create(valid_changeset))
  end

  test ".set_confirmed_at sets the confirmed_at field on a changeset" do
    changeset = User.changeset(%User{}, %{}) |> UserSignup.set_confirmed_at("some_key")
    refute changeset.changes.confirmed_at == nil
  end

  test ".set_api_keys sets the api_id and api_key on a changeset" do
    changeset = User.changeset(%User{}, %{}) |> UserSignup.set_api_keys
    refute changeset.changes.api_id == nil
    refute changeset.changes.api_key == nil
  end
end
