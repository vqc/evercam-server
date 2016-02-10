defmodule EvercamMedia.Snapshot.Storage do
  require Logger
  alias Calendar.DateTime
  alias Calendar.Strftime

  def save(camera_exid, timestamp, image) do
    file_path = construct_file_path(camera_exid, timestamp)
    File.write!(file_path, image)
  end

  def construct_file_path(camera_exid, timestamp) do
    timestamp
    |> DateTime.Parse.unix!
    |> Strftime.strftime!("snapshots/#{camera_exid}/recordings/%Y/%m/%d/%H/%M/%S.jpg")
  end
end
