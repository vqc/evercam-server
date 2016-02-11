defmodule EvercamMedia.Util do
  use Calendar
  alias Calendar.DateTime
  alias Calendar.NaiveDateTime
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
      <<0xFF,0xD8, _data :: binary>> -> true
      _ -> false
    end
  end

  def encode_token(args) do
    message = format_token_message(args)
    encrypted_message = :crypto.block_encrypt(
      :aes_cbc256,
      System.get_env["SNAP_KEY"],
      System.get_env["SNAP_IV"],
      message)
    Base.url_encode64(encrypted_message)
  end

  def decode_token(token) do
   encrypted_message = Base.url_decode64!(token)
    message = :crypto.block_decrypt(
      :aes_cbc256,
      System.get_env["SNAP_KEY"],
      System.get_env["SNAP_IV"],
      encrypted_message)
    String.split(message, "|")
  end

  def broadcast_snapshot(camera_exid, image, timestamp) do
    EvercamMedia.Endpoint.broadcast(
      "cameras:#{camera_exid}",
      "snapshot-taken",
      %{image: Base.encode64(image), timestamp: timestamp})
  end

  def error_handler(error) do
    Logger.error inspect(error)
    Logger.error Exception.format_stacktrace System.stacktrace
  end

  defp format_token_message(args) do
    [""]
    |> Enum.into(args)
    |> Enum.join("|")
    |> pad_token_message
  end

  defp pad_token_message(message) do
    case rem(String.length(message), 16) do
      0 -> message
      _ -> pad_token_message("#{message} ")
    end
  end

  def format_snapshot_id(camera_id, snapshot_timestamp) do
    "#{camera_id}_#{format_snapshot_timestamp(snapshot_timestamp)}"
  end

  def format_snapshot_timestamp(<<snapshot_timestamp::bytes-size(14)>>) do
    "#{snapshot_timestamp}000"
  end

  def format_snapshot_timestamp(<<snapshot_timestamp::bytes-size(17), _rest :: binary>>) do
    snapshot_timestamp
  end

  def snapshot_timestamp_to_unix(timestamp) do
    {:ok, timestamp, _} = NaiveDateTime.Parse.asn1_generalized timestamp
    timestamp |> NaiveDateTime.to_date_time_utc |> DateTime.Format.unix
  end
end
