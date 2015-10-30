defmodule EvercamMedia.UserMailer do
  use Mailgun.Client,
    domain: Application.get_env(:evercam_media, :mailgun_domain),
    key: Application.get_env(:evercam_media, :mailgun_key)


  def confirm(user, code) do
    send_email to: user.email,
               subject: "Evercam Confirmation",
               from: sender_email,
               html: Phoenix.View.render_to_string(EvercamMedia.EmailView, "confirm.html", user: user, code: code),
               text: Phoenix.View.render_to_string(EvercamMedia.EmailView, "confirm.txt", user: user, code: code)
  end

  def camera_offline(user, camera) do
    send_email to: user.email,
               subject: "Evercam Camera Offline",
               from: sender_email,
               html: Phoenix.View.render_to_string(EvercamMedia.EmailView, "offline.html", user: user, camera: camera),
               text: Phoenix.View.render_to_string(EvercamMedia.EmailView, "offline.txt", user: user, camera: camera)
  end

  defp sender_email do
    Application.get_env(:evercam_media, EvercamMedia.Endpoint)[:email]
  end
end
