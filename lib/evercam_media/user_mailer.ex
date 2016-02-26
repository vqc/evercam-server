defmodule EvercamMedia.UserMailer do
  alias EvercamMedia.Snapshot.Storage
  @config Application.get_env(:evercam_media, :mailgun)
  @from Application.get_env(:evercam_media, EvercamMedia.Endpoint)[:email]

  def confirm(user, code) do
    Mailgun.Client.send_email @config,
      to: user.email,
      subject: "Evercam Confirmation",
      from: @from,
      html: Phoenix.View.render_to_string(EvercamMedia.EmailView, "confirm.html", user: user, code: code),
      text: Phoenix.View.render_to_string(EvercamMedia.EmailView, "confirm.txt", user: user, code: code)
  end

  def camera_online(user, camera) do
    Mailgun.Client.send_email @config,
      to: user.email,
      subject: "Evercam Camera Online",
      from: @from,
      html: Phoenix.View.render_to_string(EvercamMedia.EmailView, "online.html", user: user, camera: camera, thumbnail: thumbnail(camera)),
      text: Phoenix.View.render_to_string(EvercamMedia.EmailView, "online.txt", user: user, camera: camera, thumbnail: thumbnail(camera))
  end

  def camera_offline(user, camera) do
    Mailgun.Client.send_email @config,
      to: user.email,
      subject: "Evercam Camera Offline",
      from: @from,
      html: Phoenix.View.render_to_string(EvercamMedia.EmailView, "offline.html", user: user, camera: camera, thumbnail: thumbnail(camera)),
      text: Phoenix.View.render_to_string(EvercamMedia.EmailView, "offline.txt", user: user, camera: camera, thumbnail: thumbnail(camera))
  end

  defp thumbnail(camera) do
    thumbnail_exists? = Storage.thumbnail_exists?(camera.exid)
    cond do
      thumbnail_exists? ->
        image = Storage.thumbnail_load(camera.exid)
        data = "data:image/jpeg;base64,#{Base.encode64(image)}"
      true ->
        nil
    end
  end
end
