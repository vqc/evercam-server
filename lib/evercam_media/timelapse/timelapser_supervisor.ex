defmodule EvercamMedia.Timelapse.TimelapserSupervisor do
  @moduledoc """
  Provides function to manage timelapse workers
  """

  use Supervisor
  require Logger
  alias EvercamMedia.Timelapse.Timelapser

  @root_dir Application.get_env(:evercam_media, :storage_dir)

  @event_handlers [
    EvercamMedia.Timelapse.PollHandler,
    EvercamMedia.Timelapse.StorageHandler
  ]

  def start_link() do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    Task.start_link(&initiate_workers/0)
    children = [worker(Timelapser, [], restart: :permanent)]
    supervise(children, strategy: :simple_one_for_one, max_restarts: 1_000_000)
  end

  @doc """
  Start timelapse worker
  """
  def start_timelapse_worker(nil), do: :noop
  def start_timelapse_worker(timelapse) do
    case get_config(timelapse) do
      {:ok, settings} ->
        Logger.debug "[#{settings.name}] Starting timelapse worker"
        Supervisor.start_child(__MODULE__, [settings])
      {:error, _message, url} ->
        Logger.warn "[#{timelapse.exid}] Skipping timelapse worker as the host is invalid: #{url}"
    end
  end

  @doc """
  Reinitialize timelapse worker with new configuration
  """
  def update_worker(nil, _timelapse), do: :noop
  def update_worker(worker, timelapse) do
    case get_config(timelapse) do
      {:ok, settings} ->
        Logger.debug "Updating worker for #{settings.name}"
        # Timelapser.update_config(worker, settings)
      {:error, _message} ->
        Logger.info "Skipping timelapse worker update as the arguments are invalid"
    end
  end

  @doc """
  Start a worker for each timelapse in the database.

  This function is intended to be called after the EvercamMedia.Timelapse.TimelapserSupervisor
  is initiated.
  """
  def initiate_workers do
    Logger.info "Initiate workers for timelapse."
    # Timelapse.all |> Enum.map(&(start_timelapse_worker &1))
  end

  @doc """
  Given a timelapse, it returns a map of values required for starting a timelapse worker.
  """
  def get_config(timelapse) do
    {
      :ok,
      %{
        event_handlers: @event_handlers,
        name: timelapse.exid |> String.to_atom,
        config: %{
          timelapse_id: timelapse.id,
          camera_exid: timelapse.camera.exid,
          camera_name: timelapse.camera.name,
          title: timelapse.title,
          url: Camera.snapshot_url(timelapse.camera),
          auth: Camera.auth(timelapse.camera),
          vendor_exid: Camera.get_vendor_attr(timelapse.camera, :exid),
          timezone: Camera.get_timezone(timelapse.camera),
          date_always: timelapse.date_always,
          time_always: timelapse.time_always,
          from_date: timelapse.from_date,
          to_date: timelapse.to_date,
          file_index: get_file_index(timelapse.camera.exid, timelapse.exid),
          hls_created: is_hls_created(timelapse.camera.exid, timelapse.exid),
          sleep: timelapse.frequency * 60 * 1000
        }
      }
    }
  end

  defp is_hls_created(camera_id, timelapse_id) do
    hls_path = "#{@root_dir}/#{camera_id}/timelapse/#{timelapse_id}/ts/"
    case File.exists?(hls_path) do
      true ->
        Enum.count(File.ls!(hls_path)) > 0
      _ ->
        false
    end
  end

  defp get_file_index(camera_id, timelapse_id) do
    images_path = "#{@root_dir}/#{camera_id}/timelapse/#{timelapse_id}/images/"
    case File.exists?(images_path) do
      true ->
        Enum.count(File.ls!(images_path))
      _ ->
        0
    end
  end

  defp create_directory_structure(camera_id, timelapse_id) do
    timelapse_path = "#{@root_dir}/#{camera_id}/timelapse/#{timelapse_id}/"
    File.mkdir_p(timelapse_path)
    File.mkdir_p("#{timelapse_path}ts")
    File.mkdir_p("#{timelapse_path}images")
    create_bash_file(timelapse_path)
    create_manifest_file(timelapse_path)
    # case File.exists?(timelapse_path) do
    #   true ->
    #     false
    #   _ ->
    #     false
    # end
  end

  defp create_bash_file(timelapse_path) do
    imagesPath = "#{timelapse_path}images/"
    tsPath = "#{timelapse_path}ts/"

    bash_content = "#!/bin/bash"
    bash_content = bash_content <> "\nffmpeg -threads 1 -y -framerate 24 -i #{imagesPath}/%d.jpg -c:v libx264 -pix_fmt yuv420p -profile:v baseline -level 2.1 -maxrate 500K -bufsize 2M -crf 18 -r 24 -g 30  -f hls -hls_time 2 -hls_list_size 0 -s 480x270 #{tsPath}/low.m3u8"
    bash_content = bash_content <> "\nffmpeg -threads 1 -y -framerate 24 -i #{imagesPath}/%d.jpg -c:v libx264 -pix_fmt yuv420p -profile:v baseline -level 3.1 -maxrate 1M -bufsize 3M -crf 18 -r 24 -g 72 -f hls -hls_time 2 -hls_list_size 0 -s 640x360 #{tsPath}/medium.m3u8"
    bash_content = bash_content <> "\nffmpeg -threads 1 -y -framerate 24 -i #{imagesPath}/%d.jpg -c:v libx264 -pix_fmt yuv420p -profile:v high -level 3.2 -maxrate 4M -crf 18 -r 24 -g 100 -f hls -hls_time 2 -hls_list_size 0 #{tsPath}/high.m3u8"
    File.write("#{timelapse_path}build.sh", bash_content)
  end

  defp create_manifest_file(timelapse_path) do
    m3u8_file = "#EXTM3U"
    m3u8_file = m3u8_file <> "\n#EXT-X-STREAM-INF:BANDWIDTH=500000"
    m3u8_file = m3u8_file <> "\nts/low.m3u8"
    m3u8_file = m3u8_file <> "\n#EXT-X-STREAM-INF:BANDWIDTH=1000000"
    m3u8_file = m3u8_file <> "\nts/medium.m3u8"
    m3u8_file = m3u8_file <> "\n#EXT-X-STREAM-INF:BANDWIDTH=4000000"
    m3u8_file = m3u8_file <> "\nts/high.m3u8"
    File.write("#{timelapse_path}index.m3u8", m3u8_file)
  end
end
