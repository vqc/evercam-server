defmodule EvercamMedia.Auth do
  def validate("", ""), do: :valid
  def validate(api_id, api_key) do
    cond do
      user = User.get_by_api_keys(api_id, api_key) -> {:valid, user}
      client = Client.get_by_api_keys(api_id, api_key) -> {:valid, client}
      true -> :invalid
    end
  end
end
