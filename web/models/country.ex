defmodule Country do
  use EvercamMedia.Web, :model

  @required_fields ~w(name iso3166_a2)
  @optional_fields ~w()

  schema "countries" do
    has_many :users, User

    field :iso3166_a2, :string
    field :name, :string
  end

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:iso3166_a2, [name: "ux_countries_iso3166_a2"])
  end
end
