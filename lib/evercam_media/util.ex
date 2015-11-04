defmodule EvercamMedia.Util do
  require Logger

  @doc ~S"""
  Checks if a given binary data is a valid jpeg or not

  ## Examples

      iex> EvercamMedia.Util.is_jpeg("string")
      false

      iex> EvercamMedia.Util.is_jpeg("binaryimage")
      true
  """

  def is_jpeg(data) do
    case data do
      <<0xFF,0xD8, data :: binary>> -> true
      _ -> false
    end
  end

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

  def broadcast_snapshot(camera_id, image) do
    EvercamMedia.Endpoint.broadcast(
      "cameras:#{camera_id}",
      "snapshot-taken",
      %{image: Base.encode64(image)}
    )
  end

  def s3_file_url(file_name) do
    configure_erlcloud
    "/" <> name = file_name
    name   = String.to_char_list(name)
    bucket = System.get_env("AWS_BUCKET") |> String.to_char_list
    {expires, host, uri} = :erlcloud_s3.make_link(100000000, bucket, name)
    "#{to_string(host)}#{to_string(uri)}"
  end

  def error_handler(error) do
    Logger.error inspect(error)
    Logger.error Exception.format_stacktrace System.stacktrace
  end

  defp configure_erlcloud do
    :erlcloud_s3.configure(
      to_char_list(System.get_env["AWS_ACCESS_KEY"]),
      to_char_list(System.get_env["AWS_SECRET_KEY"])
    )
  end
end
