defmodule EvercamMedia.Snapshot.Storage do
  require Logger
  alias Calendar.DateTime
  alias Calendar.Strftime

  def save(camera_exid, timestamp, image) do
    directory_path = construct_directory_path(camera_exid, timestamp)
    file_name = construct_file_name(timestamp)
    File.mkdir_p!(directory_path)
    File.write!("#{directory_path}#{file_name}", image)
  end

  def construct_directory_path(camera_exid, timestamp) do
    root_dir = Application.get_env(:evercam_media, :storage_dir)
    timestamp
    |> DateTime.Parse.unix!
    |> Strftime.strftime!("#{root_dir}/#{camera_exid}/snapshots/recordings/%Y/%m/%d/%H/")
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
end
