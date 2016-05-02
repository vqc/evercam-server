defmodule EvercamMedia.UserView do
  use EvercamMedia.Web, :view
  alias EvercamMedia.Util

  def render("show.json", %{user: user}) do
    %{
      users: [
        %{
          id: user.username,
          firstname: user.firstname,
          lastname: user.lastname,
          username: user.username,
          email: user.email,
          country: User.get_country_attr(user, :iso3166_a2),
          stripe_customer_id: user.stripe_customer_id,
          created_at: Util.format_timestamp(user.created_at),
          updated_at: Util.format_timestamp(user.updated_at),
          confirmed_at: Util.format_timestamp(user.confirmed_at),
        }
      ]
    }
  end
end
