defmodule EvercamMedia.Snapshot.S3 do
  @moduledoc """
  TODO
  """

  alias Calendar.DateTime
  import String, only: [contains?: 2, replace_trailing: 3]
  require Logger

  def upload(camera_exid, timestamp, image) do
    Logger.debug "[#{camera_exid}] [snapshot_upload] [#{timestamp}]"
    file_path = "/#{camera_exid}/snapshots/#{timestamp}.jpg"
    date = DateTime.now!("UTC") |> DateTime.Format.httpdate
    host = "#{System.get_env("AWS_BUCKET")}.s3.amazonaws.com"
    url = "#{host}#{file_path}"
    content_type = "image/jpeg"
    string = "PUT\n\n#{content_type}\n#{date}\n/#{System.get_env("AWS_BUCKET")}#{file_path}"
    signature = :crypto.hmac(:sha, "#{System.get_env("AWS_SECRET_KEY")}", string) |> Base.encode64
    authorization = "AWS #{System.get_env("AWS_ACCESS_KEY")}:#{signature}"

    headers = [
      "Host": host,
      "Date": date,
      "Content-Type": content_type,
      "Authorization": authorization
    ]

    HTTPoison.put(url, image, headers)
  end

  def delete(camera_exid, prefix_list) do
    Enum.each(prefix_list, fn(prefix) ->
      Logger.info "[#{camera_exid}] [snapshot_delete_s3] [#{prefix}]"
      Porcelain.shell("s4cmd del s3://#{System.get_env("AWS_BUCKET")}/#{camera_exid}/snapshots/#{prefix}* --dry-run")
    end)
  end

  def list_prefixes(first, last) do
    build_prefix_list(first, first, last)
  end

  defp build_prefix_list(current, first, last, array \\ []) do
    current = increment_current(current, first, last)
    if current < last do
      prefix = current |> to_string |> replace_trailing("0", "") |> format_prefix(first, last)
      array = Enum.into([prefix], array)
      build_prefix_list(current, first, last, array)
    else
      array
    end
  end

  defp increment_current(current, first, last) do
    start_current_suffix = suffix_length(first, current)
    last_current_suffix = suffix_length(last, current)
    factor =
      case start_current_suffix < last_current_suffix do
        true -> start_current_suffix - 1
        false -> last_current_suffix - 1
      end

    cond do
      factor < 0 -> current + 1
      true -> current + round(:math.pow(10, factor))
    end
  end

  defp longest_common_prefix(first, last) do
    index = Enum.find_index(0..String.length(first), fn i -> String.at(first, i) != String.at(last, i) end)
    if index, do: String.slice(first, 0, index), else: first
  end

  defp suffix_length(first, last) do
    common_prefix_length = longest_common_prefix(to_string(first), to_string(last)) |> String.length
    start_length = first |> to_string |> String.length
    start_length - common_prefix_length
  end

  defp format_prefix(prefix, first, last) do
    if contains?(to_string(first), prefix) ||
      contains?(to_string(last), prefix) &&
      String.length(to_string(first)) > String.length(prefix) &&
      String.length(to_string(last)) > String.length(prefix) do
      format_prefix("#{prefix}0", first, last)
    else
      prefix
    end
  end
end
