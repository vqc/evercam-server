defmodule EvercamMedia.Auth do
  def validate(api_id, api_key) do
    if present?(api_id) && present?(api_key) do
      case EvercamMedia.Repo.one(User.find_by_api_keys(api_id, api_key)) do
        %User{} ->
          :valid
        nil ->
          :invalid
      end
    else
      :invalid
    end
  end

  defp present?(str) do
    is_binary(str) && str != ""
  end
end
