defmodule VendorModel do
  use EvercamMedia.Web, :model
  import Ecto.Query
  alias EvercamMedia.Repo

  schema "vendor_models" do
    belongs_to :vendor, Vendor, foreign_key: :vendor_id
    has_many :cameras, Camera

    field :exid, :string
    field :name, :string
    field :username, :string
    field :password, :string
    field :jpg_url, :string
    field :h264_url, :string
    field :mjpg_url, :string
    field :shape, :string
    field :resolution, :string
    field :official_url, :string
    field :more_info, :string
    field :audio_url, :string
    field :poe, :boolean
    field :wifi, :boolean
    field :upnp, :boolean
    field :ptz, :boolean
    field :infrared, :boolean
    field :varifocal, :boolean
    field :sd_card, :boolean
    field :audio_io, :boolean
    field :discontinued, :boolean
    field :onvif, :boolean
    field :psia, :boolean
    field :config, EvercamMedia.Types.JSON
  end

  def by_exid(exid) do
    VendorModel
    |> where(exid: ^exid)
    |> preload(:vendor)
    |> Repo.one
  end

  def get_url(model, attr \\ "jpg") do
    "#{model.config["snapshots"]["#{attr}"]}"
  end

  def get_image_url(model_full, type \\ "original") do
    "https://evercam-public-assets.s3.amazonaws.com/#{model_full.vendor.exid}/#{model_full.exid}/#{type}.jpg"
  end
end
