defmodule EvercamMedia.Snapshot.Storage do
  use Calendar
  require Logger
  alias EvercamMedia.Util

  @root_dir Application.get_env(:evercam_media, :storage_dir)
  @seaweedfs Application.get_env(:evercam_media, :seaweedfs_url)

  def seaweedfs_save(camera_exid, timestamp, image, notes) do
    hackney = [pool: :seaweedfs_upload_pool]
    app_name = notes_to_app_name(notes)
    directory_path = construct_directory_path(camera_exid, timestamp, app_name, "")
    file_name = construct_file_name(timestamp)
    file_path = directory_path <> file_name
    HTTPoison.post!("#{@seaweedfs}#{file_path}", {:multipart, [{file_path, image, []}]}, [], hackney: hackney)
    case HTTPoison.put("#{@seaweedfs}/#{camera_exid}/snapshots/thumbnail.jpg", {:multipart, [{file_path, image, []}]}, [], hackney: hackney) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        :noop
      _ ->
        HTTPoison.post!("#{@seaweedfs}/#{camera_exid}/snapshots/thumbnail.jpg", {:multipart, [{file_path, image, []}]}, [], hackney: hackney)
    end
  end

  def seaweedfs_load_range(camera_exid, from) do
    with {:ok, response} <- HTTPoison.get("#{@seaweedfs}/#{camera_exid}/snapshots/"),
         %HTTPoison.Response{status_code: 200, body: body} <- response,
         {:ok, data} <- Poison.decode(body),
          true <- is_list(data["Subdirectories"]) do
      snapshots =
        data["Subdirectories"]
        |> Enum.flat_map(fn(dir) -> do_seaweedfs_load_range(camera_exid, from, dir["Name"]) end)
      {:ok, snapshots}
    end
  end

  defp do_seaweedfs_load_range(camera_exid, from, app_name) do
    hackney = [pool: :seaweedfs_download_pool]
    directory_path = construct_directory_path(camera_exid, from, app_name, "")

    with {:ok, response} <- HTTPoison.get("#{@seaweedfs}#{directory_path}?limit=3600", [], hackney: hackney),
         %HTTPoison.Response{status_code: 200, body: body} <- response,
         {:ok, data} <- Poison.decode(body),
         true <- is_list(data["Files"]) do
      {:ok, Enum.map(data["Files"], fn(file) -> construct_snapshot_record(directory_path, file, app_name) end)}
    end
    |> case do
      {:ok, snapshots} -> snapshots
      _ -> []
    end
  end

  def thumbnail_load(camera_exid) do
    case HTTPoison.get("#{@seaweedfs}/#{camera_exid}/snapshots/thumbnail.jpg", [], hackney: [pool: :seaweedfs_upload_pool]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: thumbnail}} ->
        {:ok, thumbnail}
      {:ok, %HTTPoison.Response{status_code: 404}} ->
        thumbnail = file_thumbnail_load(camera_exid)
        spawn fn -> HTTPoison.post!("#{@seaweedfs}/#{camera_exid}/snapshots/thumbnail.jpg", {:multipart, [{"", thumbnail, []}]}, [], hackney: [pool: :seaweedfs_upload_pool]) end
        {:ok, thumbnail}
      error ->
        Logger.error inspect(error)
        {:error, Util.unavailable}
    end
  end

  def file_thumbnail_load(camera_exid) do
    thumbnail_path = "#{@root_dir}/#{camera_exid}/snapshots/thumbnail.jpg"
    file =
      System.cmd("readlink", [thumbnail_path])
      |> elem(0)
      |> String.replace_trailing("\n", "")
      |> File.open([:read, :binary, :raw], fn(file) -> IO.binread(file, :all) end)
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
    app_name = notes_to_app_name(notes)
    directory_path = construct_directory_path(camera_exid, timestamp, app_name)
    file_name = construct_file_name(timestamp)
    :filelib.ensure_dir(to_char_list(directory_path))
    File.open("#{directory_path}#{file_name}", [:write, :binary, :raw], fn(file) -> IO.binwrite(file, image) end)
  end

  def load(camera_exid, snapshot_id, notes) do
    app_name = notes_to_app_name(notes)
    timestamp =
      snapshot_id
      |> String.split("_")
      |> List.last
      |> Util.snapshot_timestamp_to_unix
    directory_path = construct_directory_path(camera_exid, timestamp, app_name)
    file_name = construct_file_name(timestamp)
    File.open("#{directory_path}#{file_name}", [:read, :binary, :raw], fn(file) ->
      IO.binread(file, :all)
    end)
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
      Porcelain.shell("ionice -c 3 find '#{dir_path}' -exec sleep 0.01 \\; -delete")
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

  defp construct_snapshot_record(directory_path, file, app_name) do
    %{
      created_at: parse_file_timestamp(directory_path, file["name"]),
      notes: app_name_to_notes(app_name),
      motion_level: nil
    }
  end

  defp parse_file_timestamp(directory_path, file_path) do
    [_, _, _, year, month, day, hour] = String.split(directory_path, "/", trim: true)
    [minute, second, _] = String.split(file_path, "_")

    DateTime.Parse.rfc3339_utc("#{year}-#{month}-#{day}T#{hour}:#{minute}:#{second}Z")
    |> elem(1)
    |> DateTime.Format.unix
  end

  def format_file_name(<<file_name::bytes-size(6)>>) do
    "#{file_name}000" <> ".jpg"
  end

  def format_file_name(<<file_name::bytes-size(9), _rest :: binary>>) do
    "#{file_name}" <> ".jpg"
  end

  def app_name_to_notes(name) do
    case name do
      "recordings" -> "Evercam Proxy"
      "thumbnail" -> "Evercam Thumbnail"
      "timelapse" -> "Evercam Timelapse"
      "snapmail" -> "Evercam SnapMail"
      _ -> "User Created"
    end
  end

  def notes_to_app_name(notes) do
    case notes do
      "Evercam Proxy" -> "recordings"
      "Evercam Thumbnail" -> "thumbnail"
      "Evercam Timelapse" -> "timelapse"
      "Evercam SnapMail" -> "snapmail"
      _ -> "archives"
    end
  end
end
