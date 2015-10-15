defmodule EvercamMedia.UserMailer do
  use Mailgun.Client, Application.get_env(:evercam_media, :mailgun_config)
 
  def confirm(user, code) do
    send_email to: user.email,
               subject: "Evercam Confirmation",
               from: sender_email,
               html: Phoenix.View.render_to_string(EvercamMedia.EmailView, "confirm.html", user: user, code: code),
               text: Phoenix.View.render_to_string(EvercamMedia.EmailView, "confirm.txt", user: user, code: code)
  end

  defp sender_email do
    Application.get_env(:evercam_media, EvercamMedia.Endpoint)[:email]
  end
end
