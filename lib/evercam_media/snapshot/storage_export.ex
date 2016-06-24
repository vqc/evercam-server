defmodule EvercamMedia.Snapshot.Storage.Export do
  require Logger
  alias EvercamMedia.Snapshot.Storage

  @root_dir Application.get_env(:evercam_media, :storage_dir)
  @seaweedfs Application.get_env(:evercam_media, :seaweedfs_url)
  @hackney_opts [pool: :seaweedfs_upload_pool]

  def queue_for_export(camera_exid) do
    "#{@root_dir}/#{camera_exid}/snapshots/*/2016/"
    |> Path.wildcard
    |> Enum.reject(fn(year_path) -> year_path == "#{@root_dir}/#{camera_exid}/snapshots/thumbnail/2016" end)
    |> Enum.flat_map(fn(year_path) -> Path.wildcard("#{year_path}/??/??/") end)
    |> Enum.each(fn(dir_path) -> Exq.enqueue(Exq, "export_dir_day", __MODULE__, [dir_path, "export_dir_day"]) end)
  end

  def perform(dir_path, "export_dir_day") do
    "#{dir_path}/??/"
    |> Path.wildcard
    |> Enum.each(fn(dir_path) -> Exq.enqueue(Exq, "export_dir_hour", __MODULE__, [dir_path, "export_dir_hour"]) end)
  end

  def perform(dir_path, "export_dir_hour") do
    "#{dir_path}/??_??_???.jpg"
    |> Path.wildcard
    |> Enum.each(fn(file_path) -> Exq.enqueue(Exq, "file", __MODULE__, [file_path, "file"]) end)
  end

  def perform(file_path, "file") do
    url_path = String.replace(file_path, @root_dir, "")

    file_path
    |> File.open([:read, :binary, :raw], fn(pid) -> IO.binread(pid, :all) end)
    |> case do
      {:ok, image} ->
        HTTPoison.post!("#{@seaweedfs}#{url_path}", {:multipart, [{url_path, image, []}]}, [], hackney: @hackney_opts)
        File.rm!(file_path)
      _ ->
        raise "[storage_export] Reading file #{file_path} failed!"
    end
  end

  def export_thumbnails do
    "#{@root_dir}/*/snapshots/thumbnail.jpg"
    |> Path.wildcard
    |> Enum.each(fn(path) ->
      case File.read(path) do
        {:ok, image} ->
          Storage.seaweedfs_thumbnail_export(path, image)
          File.rm!(path)
          File.write!(path, image)
        {:error, :enoent} ->
          image =
            path
            |> String.replace_leading("#{@root_dir}/", "")
            |> String.replace_trailing("/snapshots/thumbnail.jpg", "")
            |> Storage.latest
            |> File.read!
          Storage.seaweedfs_thumbnail_export(path, image)
          File.rm!(path)
          File.write!(path, image)
      end
    end)
  end

  def delete_thumbnails do
    "#{@root_dir}/*/snapshots/thumbnail/"
    |> Path.wildcard
    |> Enum.each(fn(path) -> File.rm_rf!(path) end)
  end
end
