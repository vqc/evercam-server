defmodule EvercamMedia.Snapshot.S3 do
  @moduledoc """
  TODO
  """

  alias Calendar.DateTime

  def upload(camera_exid, timestamp, image) do
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

  def delete(snapshot, camera_exid) do
    # NOTE: simplify timestamp conversion
    timestamp = Ecto.DateTime.to_erl(snapshot.created_at)
    {:ok, timestamp} = Calendar.DateTime.from_erl(timestamp, "UTC")
    timestamp = Calendar.DateTime.Format.unix(timestamp)
    file_path = "#{camera_exid}/snapshots/#{timestamp}.jpg"
    s3_bucket = "#{System.get_env("AWS_BUCKET")}"

    ExAws.S3.delete_object(s3_bucket, file_path)
  end
end
