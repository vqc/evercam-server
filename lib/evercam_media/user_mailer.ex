defmodule EvercamMedia.UserMailer do
  use Calendar
  alias EvercamMedia.Snapshot.Storage

  @config Application.get_env(:evercam_media, :mailgun)
  @from Application.get_env(:evercam_media, EvercamMedia.Endpoint)[:email]
  @year DateTime.now_utc |> Strftime.strftime!("%Y")

  def confirm(user, code) do
    Mailgun.Client.send_email @config,
      to: user.email,
      subject: "Evercam Confirmation",
      from: @from,
      html: Phoenix.View.render_to_string(EvercamMedia.EmailView, "confirm.html", user: user, code: code, year: @year),
      text: Phoenix.View.render_to_string(EvercamMedia.EmailView, "confirm.txt", user: user, code: code)
  end

  def camera_status(status, user, camera) do
    thumbnail = get_thumbnail(camera)
    Mailgun.Client.send_email @config,
      to: user.email,
      subject: "Evercam Camera \"#{camera.name}\" is now #{status}",
      from: @from,
      attachments: get_attachments(thumbnail),
      html: Phoenix.View.render_to_string(EvercamMedia.EmailView, "#{status}.html", user: user, camera: camera, thumbnail_available: !!thumbnail, year: @year),
      text: Phoenix.View.render_to_string(EvercamMedia.EmailView, "#{status}.txt", user: user, camera: camera)
  end

  def camera_shared_notification(user, camera, sharee_email, message) do
    thumbnail = get_thumbnail(camera)
    Mailgun.Client.send_email @config,
      to: sharee_email,
      subject: "#{User.get_fullname(user)} has shared a camera with you",
      from: @from,
      attachments: get_attachments(thumbnail),
      html: Phoenix.View.render_to_string(EvercamMedia.EmailView, "camera_shared_notification.html", user: user, camera: camera, message: message, thumbnail_available: !!thumbnail, year: @year),
      text: Phoenix.View.render_to_string(EvercamMedia.EmailView, "camera_shared_notification.txt", user: user, camera: camera, message: message)
  end

  def camera_share_request_notification(user, camera, email, message, key) do
    thumbnail = get_thumbnail(camera)
    Mailgun.Client.send_email @config,
      to: email,
      subject: "#{User.get_fullname(user)} has shared a camera with you",
      from: @from,
      attachments: get_attachments(thumbnail),
      html: Phoenix.View.render_to_string(EvercamMedia.EmailView, "sign_up_to_share_email.html", user: user, camera: camera, message: message, key: key, thumbnail_available: !!thumbnail, year: @year),
      text: Phoenix.View.render_to_string(EvercamMedia.EmailView, "sign_up_to_share_email.txt", user: user, camera: camera, message: message, key: key)
  end

  defp get_thumbnail(camera) do
    case Storage.thumbnail_load(camera.exid) do
      {:ok, image} -> image
      _ -> nil
    end
  end

  defp get_attachments(thumbnail) do
    if thumbnail, do: [%{content: thumbnail, filename: "snapshot.jpg"}], else: nil
  end
end
