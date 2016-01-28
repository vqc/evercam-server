defmodule Permissions.Camera do
  import Ecto.Query
  alias EvercamMedia.Repo

  def can_edit?(user, camera_exid) do
    can_access?("edit", user, camera_exid)
  end

  def can_view?(user, camera_exid) do
    can_access?("view", user, camera_exid)
  end

  def can_snapshot?(user, camera_exid) do
    can_access?("snapshot", user, camera_exid)
  end

  def can_delete?(user, camera_exid) do
    can_access?("delete", user, camera_exid)
  end

  def can_list?(user, camera_exid) do
    can_access?("list", user, camera_exid)
  end

  def can_grant?(user, camera_exid) do
    can_access?("grant", user, camera_exid)
  end

  defp can_access?(right, user, camera_exid) do
    camera = Camera.get(camera_exid)
    is_public?(camera) or is_owner?(user, camera) or has_right?(right, user, camera)
  end

  defp has_right?(right, user, camera) do
    token = AccessToken.active_token_for(user.id)
    rights =
      AccessRight
      |> where([ar], ar.token_id == ^token.id)
      |> where([ar], ar.camera_id == ^camera.id)
      |> where([ar], ar.status == 1)
      |> where([ar], ar.right == ^right)
      |> where([ar], ar.scope == ^"cameras")
      |> Repo.all

    is_list(rights) and length(rights) > 0
  end

  defp is_owner?(user, camera) do
    user.id == camera.owner_id
  end

  defp is_public?(camera) do
    camera.is_public
  end
end
