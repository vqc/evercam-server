defmodule EvercamMedia.UserChannel do
  use Phoenix.Channel
  alias EvercamMedia.Auth

  def join("users:" <> username, params, socket) do
    send(self, {:after_join, username})
    {:ok, socket}
  end

  def handle_info({:after_join, username}, socket) do
    {:noreply, socket}
  end
end
