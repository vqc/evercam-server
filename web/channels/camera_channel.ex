defmodule EvercamMedia.CameraChannel do
  use Phoenix.Channel
  alias EvercamMedia.Snapshot.StreamerSupervisor

  def join("cameras:" <> camera_exid, _auth_msg, socket) do
    send(self, {:after_join, camera_exid})
    {:ok, socket}
  end

  def handle_info({:after_join, camera_exid}, socket) do
    StreamerSupervisor.start_streamer(camera_exid)
    {:noreply, socket}
  end
end
