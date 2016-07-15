defmodule EvercamMedia.Geocode do

  def fetch(address) do
    response = HTTPotion.get "http://maps.googleapis.com/maps/api/geocode/json?address=#{URI.encode(address)}&sensor=false"

    {:ok, results} = Poison.decode response.body

    get_in(results, ["results", Access.at(0), "geometry", "location"])
  end
end
