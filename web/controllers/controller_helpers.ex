defmodule EvercamMedia.ControllerHelpers do
  import Plug.Conn
  import Phoenix.Controller
  alias EvercamMedia.ErrorView

  def render_error(conn, status, message) do
    conn
    |> put_status(status)
    |> render(ErrorView, "error.json", %{message: message})
  end
end
