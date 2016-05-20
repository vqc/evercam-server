defmodule EvercamMedia.Util do
  use Calendar
  require Logger
  import String, only: [to_integer: 1]

  def unavailable do
    Application.app_dir(:evercam_media)
    |> Path.join("priv/static/images/unavailable.jpg")
    |> File.read!
  end

  def storage_unavailable do
    Application.app_dir(:evercam_media)
    |> Path.join("priv/static/images/storage-unavailable.jpg")
    |> File.read!
  end

  def is_jpeg(data) do
    case data do
      <<0xFF,0xD8, _data :: binary>> -> true
      _ -> false
    end
  end

  def port_open?(address, port) do
    case :gen_tcp.connect(to_char_list(address), to_integer(port), [:binary, active: false], 500) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true
      {:error, _error} ->
        false
    end
  end

  def encode(args) do
    message = format_token_message(args)
    encrypted_message = :crypto.block_encrypt(
      :aes_cbc256,
      System.get_env["SNAP_KEY"],
      System.get_env["SNAP_IV"],
      message)
    Base.url_encode64(encrypted_message)
  end

  def decode(token) do
    encrypted_message = Base.url_decode64!(token)
    message = :crypto.block_decrypt(
      :aes_cbc256,
      System.get_env["SNAP_KEY"],
      System.get_env["SNAP_IV"],
      encrypted_message)
    message |> String.split("|") |> List.delete_at(-1)
  end

  def broadcast_snapshot(camera_exid, image, timestamp) do
    EvercamMedia.Endpoint.broadcast(
      "cameras:#{camera_exid}",
      "snapshot-taken",
      %{image: Base.encode64(image), timestamp: timestamp})
  end

  def broadcast_camera_status(camera_exid, status, username) do
    EvercamMedia.Endpoint.broadcast(
      "users:#{username}",
      "camera-status-changed",
      %{camera_id: camera_exid, status: status})
  end

  def error_handler(error) do
    Logger.error inspect(error)
    Logger.error Exception.format_stacktrace System.stacktrace
  end

  def exec_with_timeout(function, timeout \\ 5) do
    try do
      Task.async(fn() -> function.() end)
      |> Task.await(:timer.seconds(timeout))
    catch _type, error ->
      Logger.error inspect(error)
      [504, %{message: "Request timed out."}]
    end
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
    timestamp
    |> NaiveDateTime.Parse.asn1_generalized
    |> elem(1)
    |> NaiveDateTime.to_date_time_utc
    |> DateTime.Format.unix
  end
end
