defmodule EvercamMedia.Auth do
  def validate(api_id, api_key) do
    if present?(api_id) && present?(api_key) do
      case User.get_by_api_keys(api_id, api_key) do
        nil ->
          :invalid
        user ->
          {:valid, user}
      end
    else
      :invalid
    end
  end

  defp present?(str) do
    is_binary(str) && str != ""
  end
end
