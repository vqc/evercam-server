defmodule EvercamMedia.Snapshot.Storage do
  use GenServer
  require Logger
  alias Calendar.DateTime
  alias Calendar.Strftime

  def upload(camera_exid, timestamp, data) do
    :poolboy.transaction StoragePool, fn worker_pid ->
      GenServer.call(worker_pid, {:upload, camera_exid, timestamp, data})
    end
  end

  def start_link([]) do
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    Process.send_after(self, :connect, 1000)
    {:ok, nil}
  end

  def handle_info(:connect, state) do
    response = :ftp.open(to_char_list(System.get_env("FTP_DOMAIN")))
    handle_connect(response, state)
  end

  def handle_connect({:ok, pid}, _state) do
    Logger.debug "Connected to the ftp server succesfully."
    :ftp.user(pid, to_char_list(System.get_env("FTP_USERNAME")),
              to_char_list(System.get_env("FTP_PASSWORD")))
    {:noreply, pid}
  end

  def handle_connect({:error, _error}, _state) do
    Logger.error "Error connecting to the ftp server. Retrying in 5 seconds..."
    Process.send_after(self, :connect, 5000)
    {:noreply, nil}
  end

  def handle_call({:upload, camera_exid, timestamp, data}, _from, state) do
    pid = state
    file_path =
      construct_file_path(camera_exid, timestamp)
      |> ensure_dir_exists(pid)
      |> to_char_list
    response = :ftp.send_bin(pid, data, file_path)
    handle_upload(response, camera_exid, timestamp, data, state)
  end

  def handle_upload(:ok, camera_exid, timestamp, _data, state) do
    Logger.debug "[#{camera_exid}] [snapshot_upload_ftp] [#{timestamp}]"
    {:reply, state, state}
  end

  def handle_upload({:error, _error}, camera_exid, timestamp, _data, state) do
    Logger.debug "[#{camera_exid}] [snapshot_upload_ftp_error] [#{timestamp}]"
    {:reply, state, state}
  end

  def ensure_dir_exists(file_path, pid) do
    file_path
    |> String.split("/")
    |> Enum.reduce("", fn(dir, path) ->
      :ftp.mkdir(pid, to_char_list(path))
      path <> "/" <> dir
    end)
  end

  def construct_file_path(camera_exid, timestamp) do
    timestamp
    |> DateTime.Parse.unix!
    |> Strftime.strftime!("snapshots/#{camera_exid}/recordings/%Y/%m/%d/%H/%M/%S.jpg")
  end
end
