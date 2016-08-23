defmodule EvercamMedia.ControllerHelpers do
  import Plug.Conn
  import Phoenix.Controller
  alias EvercamMedia.ErrorView

  def render_error(conn, status, message) do
    conn
    |> put_status(status)
    |> render(ErrorView, "error.json", %{message: message})
  end

  def get_requester_ip(nil), do: "0.0.0.0"
  def get_requester_ip(remote_ip), do: remote_ip |> Tuple.to_list |> Enum.join(".")
end
