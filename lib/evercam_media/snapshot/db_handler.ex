defmodule EvercamMedia.Snapshot.DBHandler do
  @moduledoc """
  This module should ideally delegate all the updates to be made to the database
  on various events to another module.

  Right now, this is a extracted and slightly modified from the previous version of
  worker.

  These are the list of tasks for the db handler
    * Create an entry in the snapshots table for each retrived snapshots
    * Update the CameraActivity table whenever there is a change in the camera status
    * Update the status and last_polled_at values of Camera table
    * Update the thumbnail_url of the Camera table - This was done in the previous
    version and not now. This update can be avoided if thumbnails can be dynamically
    served.
  """
  use GenEvent
  require Logger
  alias EvercamMedia.Repo
  alias EvercamMedia.SnapshotRepo
  alias EvercamMedia.Util
  alias Calendar.DateTime
  alias Calendar.Strftime

  def handle_event({:got_snapshot, data}, state) do
    {camera_exid, timestamp, image} = data
    Logger.debug "[#{camera_exid}] [snapshot_success]"
    notes = "Evercam Proxy"
    camera = Camera.get_full("#{camera_exid}")
    spawn fn -> save_snapshot_record(camera, timestamp, nil, notes) end
    spawn fn -> update_camera_status("#{camera_exid}", timestamp, true) end
    ConCache.put(:cache, camera_exid, %{image: image, timestamp: timestamp, notes: notes})
    {:ok, state}
  end

  def handle_event({:snapshot_error, data}, state) do
    {camera_exid, timestamp, error} = data
    parse_snapshot_error(camera_exid, timestamp, error)
    |> handle_snapshot_error(camera_exid, timestamp, error)
    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end

  def calculate_motion_level(_camera_exid, _image_1, nil), do: nil
  def calculate_motion_level(camera_exid, image_1, %{image: image_2}) do
    try do
      Logger.debug "[#{camera_exid}] [motion_detection] [calculating]"
      level = EvercamMedia.MotionDetection.Lib.compare(camera_exid, image_1, image_2)
      Logger.debug "[#{camera_exid}] [motion_detection] [calculated] [#{level}]"
      level
    rescue
      error ->
        Util.error_handler(error)
        nil
    end
  end

  def parse_snapshot_error(camera_exid, timestamp, error) do
    case error do
      %CaseClauseError{} ->
        :bad_request
      %HTTPotion.HTTPError{} ->
        Map.get(error, :message) |> String.to_atom
      error when is_map(error) ->
        Map.get(error, :reason)
      _ ->
        error
    end
  end

  def handle_snapshot_error(reason, camera_exid, timestamp, error) do
    case reason do
      :system_limit ->
        Logger.error "[#{camera_exid}] [snapshot_error] [system_limit] Traceback."
        Util.error_handler(error)
        [500, %{message: "Sorry, we dropped the ball."}]
      :emfile ->
        Logger.error "[#{camera_exid}] [snapshot_error] [emfile] Traceback."
        Util.error_handler(error)
        [500, %{message: "Sorry, we dropped the ball."}]
      :bad_request ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [bad_request]"
        update_camera_status("#{camera_exid}", timestamp, false, "bad_request", 50)
        [504, %{message: "Bad request."}]
      :closed ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [closed]"
        update_camera_status("#{camera_exid}", timestamp, false, "closed", 5)
        [504, %{message: "Connection closed."}]
      :nxdomain ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [nxdomain]"
        update_camera_status("#{camera_exid}", timestamp, false, "nxdomain", 100)
        [504, %{message: "Non-existant domain."}]
      :ehostunreach ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [ehostunreach]"
        update_camera_status("#{camera_exid}", timestamp, false, "ehostunreach", 20)
        [504, %{message: "No route to host."}]
      :enetunreach ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [enetunreach]"
        update_camera_status("#{camera_exid}", timestamp, false, "enetunreach", 20)
        [504, %{message: "Network unreachable."}]
      :req_timedout ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [req_timedout]"
        update_camera_status("#{camera_exid}", timestamp, false, "req_timedout", 5)
        [504, %{message: "Request to the camera timed out."}]
      :timeout ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [timeout]"
        update_camera_status("#{camera_exid}", timestamp, false, "timeout", 5)
        [504, %{message: "Camera response timed out."}]
      :connect_timeout ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [connect_timeout]"
        update_camera_status("#{camera_exid}", timestamp, false, "connect_timeout", 5)
        [504, %{message: "Connection to the camera timed out."}]
      :econnrefused ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [econnrefused]"
        update_camera_status("#{camera_exid}", timestamp, false, "econnrefused", 20)
        [504, %{message: "Connection refused."}]
      :not_found ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [not_found]"
        update_camera_status("#{camera_exid}", timestamp, false, "not_found", 100)
        [504, %{message: "Camera url is not found.", response: error[:response]}]
      :forbidden ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [forbidden]"
        update_camera_status("#{camera_exid}", timestamp, false, "forbidden", 100)
        [504, %{message: "Camera responded with a Forbidden message.", response: error[:response]}]
      :unauthorized ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [unauthorized]"
        update_camera_status("#{camera_exid}", timestamp, false, "unauthorized", 100)
        [504, %{message: "Camera responded with a Unauthorized message.", response: error[:response]}]
      :device_error ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [device_error]"
        update_camera_status("#{camera_exid}", timestamp, false, "device_error", 5)
        [504, %{message: "Camera responded with a Device Error message.", response: error[:response]}]
      :device_busy ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [device_busy]"
        update_camera_status("#{camera_exid}", timestamp, false, "device_busy", 1)
        [502, %{message: "Camera responded with a Device Busy message.", response: error[:response]}]
      :not_a_jpeg ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [not_a_jpeg]"
        update_camera_status("#{camera_exid}", timestamp, false, "device_busy", 1)
        [504, %{message: "Camera didn't respond with an image.", response: error[:response]}]
      _reason ->
        Logger.warn "[#{camera_exid}] [snapshot_error] [unhandled] #{inspect error}"
        [500, %{message: "Sorry, we dropped the ball."}]
    end
  end

  def update_camera_status(camera_exid, timestamp, status, error_code \\ "generic", error_weight \\ 0) do
    camera = Camera.get_full(camera_exid)
    old_error_total = ConCache.dirty_get_or_store(:snapshot_error, camera.exid, fn() -> 0 end)
    error_total = old_error_total + error_weight
    cond do
      status == true && camera.is_online != status ->
        change_camera_status(camera, timestamp, true)
        ConCache.dirty_put(:snapshot_error, camera.exid, 0)
        Logger.warn "[#{camera_exid}] [update_status] [online]"
      status == true ->
        ConCache.dirty_put(:snapshot_error, camera.exid, 0)
      status == false && camera.is_online != status && error_total >= 100 ->
        change_camera_status(camera, timestamp, false)
        Logger.warn "[#{camera_exid}] [update_status] [offline] [#{error_code}]"
      status == false && camera.is_online != status ->
        ConCache.dirty_put(:snapshot_error, camera.exid, error_total)
        Logger.warn "[#{camera_exid}] [update_status] [error] [#{error_code}] [#{error_total}]"
      status == false ->
        ConCache.dirty_put(:snapshot_error, camera.exid, error_total)
      true -> :noop
    end
    Camera.get_full(camera_exid)
  end

  def change_camera_status(camera, timestamp, status) do
    try do
      task = Task.async(fn() ->
        datetime =
          Calendar.DateTime.Parse.unix!(timestamp)
          |> Calendar.DateTime.to_erl
          |> Ecto.DateTime.cast!
        params = construct_camera(datetime, status, camera.is_online == status)
        changeset = Camera.changeset(camera, params)
        Repo.update!(changeset)
        ConCache.delete(:camera_full, camera.exid)
        invalidate_camera_cache(camera)
        broadcast_change_to_users(camera)
        log_camera_status(camera, status, datetime)
      end)
      Task.await(task, :timer.seconds(1))
    catch _type, error ->
      Util.error_handler(error)
    end
  end

  def invalidate_camera_cache(camera) do
    Exq.enqueue(Exq, "cache", "Evercam::CacheInvalidationWorker", camera.exid)
  end

  def broadcast_change_to_users(camera) do
    User.with_access_to(camera)
    |> Enum.each(fn(user) -> Util.broadcast_camera_status(camera.exid, camera.is_online, user.username) end)
  end

  def log_camera_status(camera, true, datetime) do
    parameters = %{camera_id: camera.id, action: "online", done_at: datetime}
    changeset = CameraActivity.changeset(%CameraActivity{}, parameters)
    SnapshotRepo.insert(changeset)
    if camera.is_online_email_owner_notification do
      EvercamMedia.UserMailer.camera_online(camera.owner, camera)
    end
  end

  def log_camera_status(camera, false, datetime) do
    parameters = %{camera_id: camera.id, action: "offline", done_at: datetime}
    changeset = CameraActivity.changeset(%CameraActivity{}, parameters)
    SnapshotRepo.insert(changeset)
    if camera.is_online_email_owner_notification do
      EvercamMedia.UserMailer.camera_offline(camera.owner, camera)
    end
  end

  def save_snapshot_record(camera, timestamp, motion_level, notes) do
    datetime =
      Calendar.DateTime.Parse.unix!(timestamp)
      |> Calendar.DateTime.to_erl
      |> Ecto.DateTime.cast!
    snapshot_timestamp =
      Calendar.DateTime.Parse.unix!(timestamp)
      |> Calendar.Strftime.strftime!("%Y%m%d%H%M%S%f")

    snapshot_id = Util.format_snapshot_id(camera.id, snapshot_timestamp)
    parameters = %{camera_id: camera.id, notes: notes, motionlevel: motion_level, created_at: datetime, snapshot_id: snapshot_id}
    changeset = Snapshot.changeset(%Snapshot{}, parameters)
    SnapshotRepo.insert(changeset)
  end

  def generate_thumbnail_url(camera_exid, timestamp) do
    iso_timestamp =
      timestamp
      |> DateTime.Parse.unix!
      |> Strftime.strftime!("%Y-%m-%dT%H:%M:%S.%f")
      |> String.slice(0, 23)
      |> String.ljust(23, ?0)
      |> String.ljust(24, ?Z)
    token = Util.encode([camera_exid, iso_timestamp])
    EvercamMedia.Endpoint.static_url <> "/v1/cameras/#{camera_exid}/thumbnail/#{iso_timestamp}?token=#{token}"
  end

  defp construct_camera(datetime, online_status, online_status_unchanged) do
    camera_params(datetime, online_status, online_status_unchanged)
  end

  defp camera_params(datetime, _, true) do
    %{updated_at: datetime, last_polled_at: datetime}
  end

  defp camera_params(datetime, false, false) do
    %{updated_at: datetime, last_polled_at: datetime, is_online: false}
  end

  defp camera_params(datetime, true, false) do
    %{updated_at: datetime, last_polled_at: datetime, is_online: true, last_online_at: datetime}
  end
end
