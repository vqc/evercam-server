defmodule EvercamMedia.S3 do
  import EvercamMedia.SnapshotFetch
  require Logger

  def upload(camera_id, image, file_path, timestamp) do
    date = Calendar.DateTime.now!("UTC") |> Calendar.DateTime.Format.httpdate
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

  def file_url(file_name) do
    configure_erlcloud
    "/" <> name = file_name
    name   = String.to_char_list(name)
    bucket = System.get_env("AWS_BUCKET") |> String.to_char_list
    {expires, host, uri} = :erlcloud_s3.make_link(100000000, bucket, name)
    "#{to_string(host)}#{to_string(uri)}"
  end

  defp configure_erlcloud do
    :erlcloud_s3.configure(
      to_char_list(System.get_env["AWS_ACCESS_KEY"]),
      to_char_list(System.get_env["AWS_SECRET_KEY"])
    )
  end
end
