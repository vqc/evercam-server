defmodule EvercamMedia.Snapshot.Storage do
  use Calendar
  require Logger
  alias EvercamMedia.Util

  @root_dir Application.get_env(:evercam_media, :storage_dir)

  def thumbnail_link(camera_exid, snapshot_path) do
    thumbnail_path = "#{@root_dir}/#{camera_exid}/snapshots/thumbnail.jpg"
    File.rm(thumbnail_path)
    File.ln_s(snapshot_path, thumbnail_path)
  end

  def thumbnail_load(camera_exid) do
    thumbnail_path = "#{@root_dir}/#{camera_exid}/snapshots/thumbnail.jpg"
    case File.lstat(thumbnail_path) do
      {:error, :enoent} ->
        File.ln_s(latest(camera_exid), thumbnail_path)
      {:ok, %File.Stat{type: :regular}} ->
        File.rm(thumbnail_path)
        File.ln_s(latest(camera_exid), thumbnail_path)
      _ -> :noop
    end
    {file_path, _status} = System.cmd("readlink", [thumbnail_path])
    file_path = String.replace_trailing(file_path, "\n", "")
    file = File.open(file_path, [:read, :binary, :raw], fn(file) -> IO.binread(file, :all) end)
    case file do
      {:ok, content} ->
        content
      {:error, :enoent} ->
        Util.unavailable
      {:error, error} ->
        Logger.error inspect(error)
        Util.unavailable
    end
  end

  def thumbnail_exists?(camera_exid) do
    case File.lstat("#{@root_dir}/#{camera_exid}/snapshots/thumbnail.jpg") do
      {:error, _error} -> false
      {:ok, %File.Stat{}} -> true
    end
  end

  def latest(camera_exid) do
    Path.wildcard("#{@root_dir}/#{camera_exid}/snapshots/*")
    |> Enum.reject(fn(x) -> String.match?(x, ~r/thumbnail.jpg/) end)
    |> Enum.reduce("", fn(type, acc) ->
      year = Path.wildcard("#{type}/????/") |> List.last
      month = Path.wildcard("#{year}/??/") |> List.last
      day = Path.wildcard("#{month}/??/") |> List.last
      hour = Path.wildcard("#{day}/??/") |> List.last
      last = Path.wildcard("#{hour}/??_??_???.jpg") |> List.last
      Enum.max_by([acc, last], fn(x) -> String.slice(x, -27, 27) end)
    end)
  end

  def save(camera_exid, timestamp, image, notes) do
    app_name = parse_note(notes)
    directory_path = construct_directory_path(camera_exid, timestamp, app_name)
    file_name = construct_file_name(timestamp)
    :filelib.ensure_dir(to_char_list(directory_path))
    File.open("#{directory_path}#{file_name}", [:write, :binary, :raw], fn(file) -> IO.binwrite(file, image) end)
    spawn fn -> thumbnail_link(camera_exid, "#{directory_path}#{file_name}") end
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
    {:ok, content} = File.open("#{directory_path}#{file_name}", [:read, :binary, :raw], fn(file) ->
      IO.binread(file, :all)
    end)
    content
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

      Logger.info "[#{camera_exid}] [snapshot_delete_disk]"
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
      Logger.info "[#{camera_exid}] [snapshot_delete_disk] [#{Date.Format.iso8601(date)}]"
      dir_path = Strftime.strftime!(date, "#{@root_dir}/#{camera_exid}/snapshots/recordings/%Y/%m/%d")
      Porcelain.shell("find '#{dir_path}' -delete")
    end
  end

  def construct_directory_path(camera_exid, timestamp, app_dir, root_dir \\ @root_dir) do
    timestamp
    |> DateTime.Parse.unix!
    |> Strftime.strftime!("#{root_dir}/#{camera_exid}/snapshots/#{app_dir}/%Y/%m/%d/%H/")
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
