defmodule EvercamMedia.Snapshot.Storage do
  require Logger
  alias Calendar.Date
  alias Calendar.DateTime
  alias Calendar.Strftime
  alias EvercamMedia.Util

  @root_dir Application.get_env(:evercam_media, :storage_dir)

  def save(camera_exid, timestamp, image, notes) do
    app_name = parse_note(notes)
    directory_path = construct_directory_path(camera_exid, timestamp, app_name)
    file_name = construct_file_name(timestamp)
    File.mkdir_p!(directory_path)
    File.write!("#{directory_path}#{file_name}", image)
  end

  def load(camera_exid, snapshot_id, notes) do
    app_name = parse_note(notes)
    timestamp =
      snapshot_id
      |> String.split("_")
      |> List.last
      |> Util.snapshot_timestamp_to_unix
    directory_path = construct_directory_path(camera_exid, timestamp, app_name)
    file_name = construct_file_name(timestamp)
    File.read!("#{directory_path}#{file_name}")
  end

  def exists?(camera_exid, snapshot_id, notes) do
    app_name = parse_note(notes)
    timestamp =
      snapshot_id
      |> String.split("_")
      |> List.last
      |> Util.snapshot_timestamp_to_unix
    directory_path = construct_directory_path(camera_exid, timestamp, app_name)
    file_name = construct_file_name(timestamp)
    File.exists?("#{directory_path}#{file_name}")
  end

  def cleanup(cloud_recording) do
    unless cloud_recording.storage_duration == -1 do
      camera_exid = cloud_recording.camera.exid
      seconds_to_day_before_expiry = (cloud_recording.storage_duration) * (24 * 60 * 60) * (-1)
      day_before_expiry =
        DateTime.now_utc
        |> DateTime.advance!(seconds_to_day_before_expiry)
        |> DateTime.to_date

      Path.wildcard("#{@root_dir}/#{camera_exid}/snapshots/recordings/????/??/??/")
      |> Enum.each(fn(path) -> delete_if_expired(camera_exid, path, day_before_expiry) end)
    end
  end

  defp delete_if_expired(camera_exid, path, day_before_expiry) do
    date =
      path
      |> String.replace_leading("#{@root_dir}/#{camera_exid}/snapshots/recordings/", "")
      |> String.replace("/", "-")
      |> Date.Parse.iso8601!

    if Calendar.Date.before?(date, day_before_expiry) do
      date
      |> Strftime.strftime!("#{@root_dir}/#{camera_exid}/snapshots/recordings/%Y/%m/%d")
      |> File.rm_rf!
      Logger.info "[#{camera_exid}] [snapshot_delete_disk] [#{Date.Format.iso8601(date)}]"
    end
  end

  def construct_directory_path(camera_exid, timestamp, app_dir) do
    timestamp
    |> DateTime.Parse.unix!
    |> Strftime.strftime!("#{@root_dir}/#{camera_exid}/snapshots/#{app_dir}/%Y/%m/%d/%H/")
  end

  def construct_file_name(timestamp) do
    timestamp
    |> DateTime.Parse.unix!
    |> Strftime.strftime!("%M_%S_%f")
    |> format_file_name
  end

  def format_file_name(<<file_name::bytes-size(6)>>) do
    "#{file_name}000" <> ".jpg"
  end

  def format_file_name(<<file_name::bytes-size(9), _rest :: binary>>) do
    "#{file_name}" <> ".jpg"
  end

  def parse_note(notes) do
    case notes do
      "Evercam Proxy" -> "recordings"
      "Evercam Thumbnail" -> "thumbnail"
      "Evercam Timelapse" -> "timelapse"
      "Evercam SnapMail" -> "snapmail"
      _ -> "archives"
    end
  end
end
