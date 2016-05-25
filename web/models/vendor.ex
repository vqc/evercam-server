defmodule Vendor do
  use EvercamMedia.Web, :model
  import Ecto.Query
  alias EvercamMedia.Repo

  schema "vendors" do
    has_many :vendor_models, VendorModel

    field :exid, :string
    field :name, :string
    field :known_macs, EvercamMedia.Types.JSON
  end

  def by_exid(exid) do
    Vendor
    |> where(exid: ^exid)
    |> preload(:vendor_models)
    |> Repo.one
  end

  def get_models_count(vendor) do
    case vendor.vendor_models do
      nil -> 0
      vendor_models -> Enum.count(vendor_models)
    end
  end
end
