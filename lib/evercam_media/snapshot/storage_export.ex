defmodule EvercamMedia.Snapshot.Storage.Export do
  require Logger
  alias EvercamMedia.Snapshot.Storage
  @root_dir Application.get_env(:evercam_media, :storage_dir)

  def export_thumbnails do
    Path.wildcard("#{@root_dir}/*/snapshots/thumbnail.jpg")
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
    Path.wildcard("#{@root_dir}/*/snapshots/thumbnail/")
    |> Enum.each(fn(path) ->
      File.rm_rf!(path)
    end)
  end
end
