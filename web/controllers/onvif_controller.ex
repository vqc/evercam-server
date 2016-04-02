defmodule EvercamMedia.ONVIFController do
  use EvercamMedia.Web, :controller
  alias EvercamMedia.ONVIFClient

  def invoke(conn, %{"service" => service, "operation" => operation}) do
    case ONVIFClient.request(conn.assigns.onvif_access_info, service, operation, conn.assigns.onvif_parameters) do
      {:ok, response} -> default_respond(conn, 200, response)
      {:error, code, response} -> default_respond(conn, code, response)
    end
  end

  defp default_respond(conn, code, response) do
    conn
    |> put_status(code)
    |> json(response)
  end
end
