defmodule Permissions.Camera do
  import Ecto.Query
  alias EvercamMedia.Repo

  def can_edit?(requester, camera_exid) do
    can_access?("edit", requester, camera_exid)
  end

  def can_view?(requester, camera_exid) do
    can_access?("view", requester, camera_exid)
  end

  def can_snapshot?(requester, camera_exid) do
    can_access?("snapshot", requester, camera_exid)
  end

  def can_delete?(requester, camera_exid) do
    can_access?("delete", requester, camera_exid)
  end

  def can_list?(requester, camera_exid) do
    can_access?("list", requester, camera_exid)
  end

  def can_grant?(requester, camera_exid) do
    can_access?("grant", requester, camera_exid)
  end

  defp can_access?(right, requester, camera_exid) do
    camera = Camera.get(camera_exid)
    is_public?(right, camera) or is_owner?(requester, camera) or has_right?(right, requester, camera)
  end

  defp has_right?(_right, nil, _camera), do: false

  defp has_right?(right, %User{} = user, camera) do
    AccessRight
    |> join(:inner, [ar], at in AccessToken, ar.token_id == at.id)
    |> where([ar, at], at.user_id == ^user.id)
    |> where([ar], ar.camera_id == ^camera.id)
    |> where([ar], ar.status == 1)
    |> where([ar], ar.right == ^right)
    |> Repo.first
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
