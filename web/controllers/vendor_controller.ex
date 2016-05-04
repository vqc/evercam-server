defmodule EvercamMedia.VendorController do
  use EvercamMedia.Web, :controller
  alias EvercamMedia.VendorView
  alias EvercamMedia.ErrorView

  def show(conn, %{"id" => exid}) do
    case Vendor.by_exid(exid) do
      nil ->
        conn
        |> put_status(404)
        |> render(ErrorView, "error.json", %{message: "Vendor not found."})
      vendor ->
        conn
        |> render(VendorView, "show.json", %{vendor: vendor})
    end
  end
end
