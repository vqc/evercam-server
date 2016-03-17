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
    thumbnail = thumbnail(camera)
    Mailgun.Client.send_email @config,
      to: user.email,
      subject: "Evercam Camera Online",
      from: @from,
      attachments: attachments(thumbnail),
      html: Phoenix.View.render_to_string(EvercamMedia.EmailView, "online.html", user: user, camera: camera, thumbnail_available: !!thumbnail),
      text: Phoenix.View.render_to_string(EvercamMedia.EmailView, "online.txt", user: user, camera: camera)
  end

  def camera_offline(user, camera) do
    thumbnail = thumbnail(camera)
    Mailgun.Client.send_email @config,
      to: user.email,
      subject: "Evercam Camera Offline",
      from: @from,
      attachments: attachments(thumbnail),
      html: Phoenix.View.render_to_string(EvercamMedia.EmailView, "offline.html", user: user, camera: camera, thumbnail_available: !!thumbnail),
      text: Phoenix.View.render_to_string(EvercamMedia.EmailView, "offline.txt", user: user, camera: camera)
  end

  defp thumbnail(camera) do
    if Storage.thumbnail_exists?(camera.exid), do: Storage.thumbnail_load(camera.exid), else: nil
  end

  defp attachments(thumbnail) do
    if thumbnail, do: [%{content: thumbnail, filename: "snapshot.jpg"}], else: nil
  end
end
