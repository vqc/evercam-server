defmodule EvercamMedia.UserControllerTest do
  alias EvercamMedia.Util
  use EvercamMedia.ConnCase

  setup do
    country = Repo.insert!(%Country{name: "Something", iso3166_a2: "SMT"})
    user = Repo.insert!(%User{firstname: "John", lastname: "Doe", username: "johndoe", email: "john@doe.com", password: Comeonin.Bcrypt.hashpwsalt("password123"), api_id: UUID.uuid4(:hex) |> String.slice(0..8), api_key: UUID.uuid4(:hex), country_id: country.id})

    params = %{
      username: "johndoe",
      email: "legend@john.com",
      firstname: "John",
      lastname: "Legend",
      password: "johnlegend123"
    }

    {:ok, user: user, params: params}
  end

  test "GET /v1/users/:id when user not found!", context do
    username = "legend"
    response = build_conn |> get("/v1/users/#{username}?api_id=#{context[:user].api_id}&api_key=#{context[:user].api_key}")
    response_body = %{"message" => "User does not exist."}

    assert response.status == 404
    assert Poison.decode!(response.resp_body) == response_body
  end

  test "GET /v1/users/:id/credentials Get users credentials", context do
    password = "password123"
    response = build_conn |> get("/v1/users/#{context[:user].username}/credentials?password=#{password}")

    assert response.status == 200
  end

  test "POST /v1/users/ when country is invalid!" do
    params = %{
      country: "pki"
    }
    response =
      build_conn()
      |> post("/v1/users", params)

    response_body = %{"message" => "Country isn't valid!"}

    assert response.status == 400
    assert Poison.decode!(response.resp_body) == response_body
  end

  test "PATCH /v1/users/ when email is not valid while update!", context do
    params = %{email: "test @test.com"}

    expected_error = %{email: ["Email format isn't valid!"]}

    changeset = User.changeset(context[:user], params)
    error = Util.parse_changeset(changeset)

    assert error == expected_error
  end
end
