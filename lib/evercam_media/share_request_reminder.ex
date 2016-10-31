defmodule EvercamMedia.ShareRequestReminder do
  @moduledoc """
  Provides functions for getting all pending shared requests and send notification

  for all those requests which are older than 7 days.
  """

  alias EvercamMedia.Repo
  alias EvercamMedia.Util

  def check_share_requests do
    CameraShareRequest.get_all_pending_requests |> Enum.map(&(send_reminder &1))
  end

  defp send_reminder(share_request) do
    last_reminder =
      share_request.updated_at
      |> Ecto.DateTime.to_erl
      |> Calendar.DateTime.from_erl!("UTC")

    current_date = Calendar.DateTime.now!("UTC")

    seconds =
      case Calendar.DateTime.diff(current_date, last_reminder) do
        {:ok, seconds, _, :after} -> seconds
        _ -> 0
      end
    send_notification(share_request, seconds)
  end

  # 7 days seconds 604800
  defp send_notification(share_request, seconds) when seconds > 604_800 do
    send_email_notification(share_request.user, share_request.camera, share_request.email, share_request.message, share_request.key)
    share_request
    |> CameraShareRequest.update_changeset(%{updated_at: Calendar.DateTime.to_erl(Calendar.DateTime.now_utc)})
    |> Repo.update
  end
  defp send_notification(_share_request, _seconds), do: :noop

  defp send_email_notification(user, camera, to_email, message, share_request_key) do
    try do
      Task.start(fn ->
        EvercamMedia.UserMailer.camera_share_request_notification(user, camera, to_email, message, share_request_key)
      end)
    catch _type, error ->
      Util.error_handler(error)
    end
  end
end
