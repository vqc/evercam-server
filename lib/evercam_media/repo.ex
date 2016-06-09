defmodule EvercamMedia.Repo do
  use Ecto.Repo, otp_app: :evercam_media
end

defmodule EvercamMedia.SnapshotRepo do
  use Ecto.Repo, otp_app: :evercam_media
  require Ecto.Query

  def exists?(queryable) do
    queryable
    |> Ecto.Query.from(select: 1, limit: 1)
    |> Ecto.Queryable.to_query
    |> EvercamMedia.SnapshotRepo.one
    |> case do
      1 -> true
      _ -> false
    end
  end
end
