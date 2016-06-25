defmodule EvercamMedia.Snapshot.Storage.Export.PoolSupervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    pool_options = [
      name: {:local, :storage_export_pool},
      worker_module: EvercamMedia.Snapshot.Storage.Export,
      max_overflow: 0,
      size: 100,
    ]

    children = [
      :poolboy.child_spec(:storage_export_pool, pool_options, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end

defmodule EvercamMedia.Snapshot.Storage.Export.Supervisor do
  use Supervisor
  alias EvercamMedia.Snapshot.Storage

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    children = [worker(Storage.Export.Worker, [], restart: :permanent)]
    supervise(children, strategy: :simple_one_for_one, max_restarts: 1_000_000)
  end
end

defmodule EvercamMedia.Snapshot.Storage.Export.Worker do
  use GenServer
  alias EvercamMedia.Snapshot.Storage

  def start_link({camera_exid, path}) do
    GenServer.start_link(__MODULE__, {camera_exid, path})
  end

  def init({camera_exid, path}) do
    Process.send_after(self, :run, 0)
    {:ok, {camera_exid, path}}
  end

  def handle_info(:run, {camera_exid, path}) do
    case :poolboy.checkout(:storage_export_pool, false) do
      :full ->
        Process.send_after(self, :run, 100)
      pid ->
        GenServer.call(pid, {:export_snapshot, camera_exid, path}, 1_000_000)
        :poolboy.checkin(:storage_export_pool, pid)
        Supervisor.terminate_child(Storage.Export.Supervisor, self)
    end
    {:noreply, {camera_exid, path}}
  end
end

defmodule EvercamMedia.Snapshot.Storage.Export do
  use GenServer
  require Logger
  alias EvercamMedia.Util
  alias EvercamMedia.Snapshot.Storage

  @root_dir Application.get_env(:evercam_media, :storage_dir)
  @seaweedfs Application.get_env(:evercam_media, :seaweedfs_url)
  @hackney_opts [pool: :seaweedfs_upload_pool]

  def start_link([]) do
    GenServer.start_link(__MODULE__, [])
  end

  def handle_call({:export_snapshot, camera_exid, path}, _from, state) do
    export_snapshot(camera_exid, path)
    {:reply, :ok, state}
  end

  def export_snapshot(camera_exid, file_path) do
    url_path = String.replace(file_path, @root_dir, "")
    file = File.open(file_path, [:read, :binary, :raw], fn(pid) -> IO.binread(pid, :all) end)

    with {:ok, image} <- file,
         true <- Util.is_jpeg(image)
    do
      HTTPoison.post!("#{@seaweedfs}#{url_path}", {:multipart, [{url_path, image, []}]}, [], hackney: @hackney_opts)
      File.rm!(file_path)
    else
      _ -> raise "[#{camera_exid}] [storage_export] Reading file #{file_path} failed!"
    end
  end

  def export(camera_exid) do
    list = get_list_of_dirs_for_export(camera_exid)
    do_export(camera_exid, list)
  end

  defp do_export(camera_exid, []) do
    Logger.warn "[#{camera_exid}] [storage_export_finish]"
  end

  defp do_export(camera_exid, [current_dir|rest]) do
    Logger.warn "[#{camera_exid}] [storage_export_start] [#{current_dir}]"
    "#{current_dir}/??_??_???.jpg"
    |> Path.wildcard
    |> Enum.each(fn(path) -> Supervisor.start_child(Storage.Export.Supervisor, [{camera_exid, path}]) end)
    wait_until_processed(current_dir)
    do_export(camera_exid, rest)
  end

  def wait_until_processed(dir) do
    :timer.sleep(300)
    case File.rmdir(dir) do
      {:error, :eexist} -> wait_until_processed(dir)
      :ok -> :noop
    end
  end

  def get_list_of_dirs_for_export(camera_exid) do
    "#{@root_dir}/#{camera_exid}/snapshots/*/2016/"
    |> Path.wildcard
    |> Enum.reject(fn(year_path) -> year_path == "#{@root_dir}/#{camera_exid}/snapshots/thumbnail/2016" end)
    |> Enum.flat_map(fn(year_path) -> Path.wildcard("#{year_path}/??/??/??/") end)
  end

  def export_thumbnails do
    "#{@root_dir}/*/snapshots/thumbnail.jpg"
    |> Path.wildcard
    |> Enum.each(fn(path) ->
      case File.read(path) do
        {:ok, image} ->
          Storage.seaweedfs_thumbnail_export(path, image)
          File.rm!(path)
          File.write!(path, image)
        {:error, :enoent} ->
          image =
            path
            |> String.replace_leading("#{@root_dir}/", "")
            |> String.replace_trailing("/snapshots/thumbnail.jpg", "")
            |> Storage.latest
            |> File.read!
          Storage.seaweedfs_thumbnail_export(path, image)
          File.rm!(path)
          File.write!(path, image)
      end
    end)
  end

  def delete_thumbnails do
    "#{@root_dir}/*/snapshots/thumbnail/"
    |> Path.wildcard
    |> Enum.each(fn(path) -> File.rm_rf!(path) end)
  end
end
