defmodule Vendor do
  use EvercamMedia.Web, :model

  schema "vendors" do
    has_many :vendor_models, VendorModel

    field :exid, :string
    field :name, :string
  end
end
