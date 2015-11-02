defmodule EvercamMedia.Util do
  def decode_request_token(token) do
    {_, encrypted_message} = Base.url_decode64(token)
    message = :crypto.block_decrypt(
      :aes_cbc256,
      System.get_env["SNAP_KEY"],
      System.get_env["SNAP_IV"],
      encrypted_message
    )
    String.split(message, "|")
  end
end
