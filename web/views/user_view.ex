defmodule EvercamMedia.UserView do
  use EvercamMedia.Web, :view

  def render("user.json", %{ user: user, token: token }) do
    %{
      user: %{
        id: user.id,
        country_id: user.country_id,
        email: user.email,
        firstname: user.firstname,
        lastname: user.lastname,
        username: user.username,
        api_id: user.api_id,
        api_key: user.api_key,
        confirmed_at: user.confirmed_at
      }
    }
  end
end
