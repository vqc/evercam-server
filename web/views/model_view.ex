defmodule EvercamMedia.ModelView do
  use EvercamMedia.Web, :view

  def render("index.json", %{models: models}) do
    %{models: render_many(models, __MODULE__, "model.json")}
  end

  def render("show.json", %{model: model}) do
    %{models: render_many([model], __MODULE__, "model.json")}
  end

  def render("model.json", %{model: model}) do
    %{
      id: model.exid,
      name: model.name,
      vendor_id: model.vendor.exid,
      username: model.username,
      password: model.password,
      jpg_url: model.jpg_url,
      h264_url: model.h264_url,
      mjpg_url: model.mjpg_url,
      shape: model.shape,
      resolution: model.resolution,
      official_url: model.official_url,
      more_info: model.more_info,
      audio_url: model.audio_url,
      poe: model.poe,
      wifi: model.wifi,
      upnp: model.upnp,
      ptz: model.ptz,
      infrared: model.infrared,
      varifocal: model.varifocal,
      sd_card: model.sd_card,
      audio_io: model.audio_io,
      discontinued: model.discontinued,
      onvif: model.onvif,
      psia: model.psia,
      defaults: %{
        snapshots: %{
          h264: VendorModel.get_url(model, "h264"),
          lowres: VendorModel.get_url(model, "lowres"),
          jpg: VendorModel.get_url(model),
          mjpg: VendorModel.get_url(model, "mjpg"),
          mpeg4: VendorModel.get_url(model, "mpeg4"),
          mobile: VendorModel.get_url(model, "mobile")
        },
        auth: %{
          basic: %{
            username: model.config["auth"]["basic"]["username"],
            password: model.config["auth"]["basic"]["password"]
          }
        }
      },
      images: %{
        icon: VendorModel.get_image_url(model, "icon"),
        thumbnail: VendorModel.get_image_url(model, "thumbnail"),
        original: VendorModel.get_image_url(model)
      }
    }
  end
end
