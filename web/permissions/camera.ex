defmodule Permissions.Camera do
  import Ecto.Query
  alias EvercamMedia.Repo

  def can_edit?(requester, camera) do
    can_access?("edit", requester, camera)
  end

  def can_view?(requester, camera) do
    can_access?("view", requester, camera)
  end

  def can_snapshot?(requester, camera) do
    can_access?("snapshot", requester, camera)
  end

  def can_delete?(requester, camera) do
    can_access?("delete", requester, camera)
  end

  def can_list?(requester, camera) do
    can_access?("list", requester, camera)
  end

  def can_grant?(requester, camera) do
    can_access?("grant", requester, camera)
  end

  defp can_access?(right, requester, camera) do
    is_public?(right, camera) or is_owner?(requester, camera) or has_right?(right, requester, camera)
  end

  defp has_right?(_right, nil, _camera), do: false

  defp has_right?(right, %User{} = user, camera) do
    Enum.any?(camera.access_rights, fn(ar) -> ar.right == right end)
  end

  defp has_right?(right, %AccessToken{} = token, camera) do
    has_camera_right?(right, token, camera) || has_account_right?(right, token)
    true
  end

  defp has_camera_right?(right, token, camera) do
    AccessRight
    |> where([ar], ar.token_id == ^token.id)
    |> where([ar], ar.status == 1)
    |> where([ar], ar.right == ^right)
    |> where([ar], ar.camera_id == ^camera.id)
    |> Repo.first
  end

  defp has_account_right?(right, token) do
    AccessRight
    |> where([ar], ar.token_id == ^token.id)
    |> where([ar], ar.account_id == ^token.grantor_id)
    |> where([ar], ar.status == 1)
    |> where([ar], ar.right == ^right)
    |> where([ar], ar.scope == "cameras")
    |> Repo.first
  end

  def is_owner?(nil, _camera), do: false
  def is_owner?(user, camera) do
    user.id == camera.owner_id
  end

  defp is_public?(right, camera) do
    case right do
      "snapshot" -> camera.is_public
      "list" -> camera.is_public
      _right -> false
    end
  end
end
