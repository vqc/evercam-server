defmodule EvercamMedia.EmailView do
  use EvercamMedia.Web, :view

  def full_name(user) do
    "#{user.firstname} #{user.lastname}"
  end
end
