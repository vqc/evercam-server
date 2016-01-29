defmodule EvercamMedia.Auth do
  def validate("", ""), do: :valid
  def validate(api_id, api_key) do
    case User.get_by_api_keys(api_id, api_key) do
      nil ->
        :invalid
      user ->
        {:valid, user}
    end
  end
end
