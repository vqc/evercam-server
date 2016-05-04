defmodule EvercamMedia.ModelController do
  use EvercamMedia.Web, :controller
  alias EvercamMedia.ModelView
  alias EvercamMedia.ErrorView
  require Logger

  def show(conn, %{"id" => exid}) do
    case VendorModel.by_exid(exid) do
      nil ->
        conn
        |> put_status(404)
        |> render(ErrorView, "error.json", %{message: "Model Not found."})
      model ->
        conn
        |> render(ModelView, "show.json", %{model: model})
    end
  end
end
