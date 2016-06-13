defmodule EvercamMedia.Snapshot.Storage.Export do
  alias EvercamMedia.Snapshot.Storage
  @root_dir Application.get_env(:evercam_media, :storage_dir)

  def export_thumbnails do
    Path.wildcard("#{@root_dir}/*/snapshots/thumbnail.jpg")
    |> Enum.each(fn(path) ->
      image = File.read!(path)
      Storage.seaweedfs_thumbnail_save(path, image)
      File.rm!(path)
      File.write!(path, image)
    end)
  end

  def delete_thumbnails do
    Path.wildcard("#{@root_dir}/*/snapshots/thumbnail/")
    |> Enum.each(fn(path) ->
      File.rm_rf!(path)
    end)
  end
end
