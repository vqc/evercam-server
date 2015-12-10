defmodule EvercamMedia.Snapshot.CamClient do
  @moduledoc """
  Client to talk with the camera for various data. Currently this only fetches snapshots.
  In future, we could expand this module to check camera status, video stream etc.
  """

  alias EvercamMedia.HTTPClient
  alias EvercamMedia.Util
  require Logger

  @doc """
  Connect to the camera and get the snapshot
  """
  def fetch_snapshot(args) do
    [username, password] = extract_auth_credentials(args)
    try do
      response =
        case args[:vendor_exid] do
          "evercam-capture" -> HTTPClient.get(:basic_auth_android, args[:url], username, password)
          "samsung" -> HTTPClient.get(:digest_auth, args[:url], username, password)
          "ubiquiti" -> HTTPClient.get(:cookie_auth, args[:url], username, password)
          _ -> HTTPClient.get(:basic_auth, args[:url], username, password)
        end
      parse_snapshot_response(response)
    rescue
      error -> {:error, error}
    end
  end


  ## Private functions

  defp parse_snapshot_response({:ok, response}) do
    case Util.is_jpeg(response.body) do
      true -> {:ok, response.body}
      _ -> {:error, %{reason: "Response not a jpeg image", response: response.body}}
    end
  end

  defp parse_snapshot_response(response) do
    response
  end

  defp extract_auth_credentials(%{vendor_exid: _vendor_exid, url: _url, username: username, password: password}) do
    [username, password]
  end

  defp extract_auth_credentials(%{vendor_exid: _vendor_exid, url: _url, auth: auth}) do
    String.split(auth, ":")
  end

  defp extract_auth_credentials(args) do
    String.split(args[:auth], ":")
  end
end
