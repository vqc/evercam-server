defmodule EvercamMedia.Auth do
  def validate("", ""), do: :valid
  def validate(api_id, api_key) do
    case User.get_by_api_keys(to_string(api_id), to_string(api_key)) do
      nil ->
        :invalid
      user ->
        {:valid, user}
    end
  end
end
