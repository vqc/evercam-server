defmodule EvercamMedia.Timelapse.Timelapser do
  @moduledoc """
  Provides functions to create timelapse
  """

  use GenServer
  alias EvercamMedia.Snapshot.CamClient
  alias EvercamMedia.Snapshot.Storage
  require Logger

  @root_dir Application.get_env(:evercam_media, :storage_dir)

  ################
  ## Client API ##
  ################

  @doc """
  Start the timelapse server for a given timelapse.
  """
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: args[:name])
  end

  @doc """
  Get the state of the timelapse worker.
  """
  def get_state(timelapse_server) do
    GenServer.call(timelapse_server, :get_state)
  end

  @doc """
  Get the configuration of the timelapse worker.
  """
  def get_config(timelapse_server) do
    GenServer.call(timelapse_server, :get_timelapse_config)
  end

  @doc """
  Update the configuration of the timelapse worker
  """
  def update_config(timelapse_server, config) do
    GenServer.cast(timelapse_server, {:update_timelapse_config, config})
  end

  @doc """
  Get a snapshot from the camera and create new of HLS if have 24 frames
  """
  def get_snapshot(timelapse_server, {:poll, timestamp}) do
    GenServer.cast(timelapse_server, {:get_camera_snapshot, timestamp})
  end

  ######################
  ## Server Callbacks ##
  ######################

  @doc """
  Initialize the timelapse server
  """
  def init(args) do
    {:ok, event_manager} = GenEvent.start_link
    {:ok, poller} = EvercamMedia.Timelapse.Poller.start_link(args)
    add_handlers(event_manager, args[:event_handlers])
    args = Map.merge args, %{
      poller: poller,
      event_manager: event_manager
    }
    {:ok, args}
  end

  @doc """
  Server callback for restarting timelapse poller
  """
  def handle_call(:restart_timelapse_poller, _from, state) do
    {:reply, nil, state}
  end

  @doc """
  Server callback for stopping timelapse poller
  """
  def handle_call(:stop_timelapse_poller, _from, state) do
    {:reply, nil, state}
  end

  @doc """
  Server callback for getting timelapse config
  """
  def handle_call(:get_timelapse_config, _from, state) do
    {:reply, get_config_from_state(:config, state), state}
  end

  @doc """
  Server callback for getting worker state
  """
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @doc """
  Get a snapshot from the camera and create new of HLS if have 24 frames
  """
  def handle_cast({:get_camera_snapshot, timestamp}, state) do
    _get_snapshots_create_hls_chunk(state, timestamp)
    {:noreply, state}
  end

  @doc """
  Server callback for updating timelapse config
  """
  def handle_cast({:update_timelapse_config, config}, state) do
    updated_config = Map.merge state, config
    GenEvent.sync_notify(state.event_manager, {:update_timelapse_config, updated_config})
    {:noreply, updated_config}
  end

  @doc """
  Server callback for camera_reply
  """
  def handle_info({:camera_reply, camera_exid, image, timestamp}, state) do
    data = {camera_exid, timestamp, image}
    GenEvent.sync_notify(state.event_manager, {:got_snapshot, data})
    {:noreply, state}
  end

  @doc """
  Take care of unknown messages which otherwise would trigger function clause mismatch error.
  """
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  #####################
  # Private functions #
  #####################

  defp add_handlers(event_manager, event_handlers) do
    Enum.each(event_handlers, &GenEvent.add_mon_handler(event_manager, &1,[]))
  end

  defp get_config_from_state(:config, state) do
    Map.get(state, :config)
  end

  defp _get_snapshots_create_hls_chunk(state, timestamp) do
    config = get_config_from_state(:config, state)
    worker = self
    get_snapshots(state, config, timestamp, worker)
  end

  defp get_snapshots(state, config, timestamp, worker) do
    spawn fn ->
      Logger.debug "Get snapshot"
      case try_snapshot(config, 1) do
        {:ok, image} ->
          send worker, {:camera_reply, config.camera_exid, image, timestamp}
          images_index = get_file_index(config.camera_exid, state.name)
          source_path = "#{@root_dir}/#{state.config.camera_exid}/timelapse/#{state.name}/images/#{images_index}.jpg"
          Logger.debug source_path
          File.write(source_path, image)
          Logger.debug "Save image"
          hls_created = is_hls_created(config.camera_exid, state.name)
          cond do
            !hls_created && images_index > 25 -> create_hls(state)
            !hls_created && images_index == 24 -> create_hls(state)
            !hls_created && images_index > 0 && images_index < 25 ->
              Logger.debug "start condition images_index > 0 && images_index < 25 "
              false
            true ->
              Logger.debug "Last condition for already created hls"
              true
          end
        {:error, _error} ->
          false
      end
    end
  end

  defp try_snapshot(config, 3) do
    timestamp = Calendar.DateTime.Format.unix(Calendar.DateTime.now_utc)
    case CamClient.fetch_snapshot(config) do
      {:ok, image} -> {:ok, image}
      {:error, error} -> {:error, error}
    end
  end

  defp try_snapshot(config, attempt) do
    case CamClient.fetch_snapshot(config) do
      {:ok, image} -> {:ok, image}
      {:error, _error} -> try_snapshot(config, attempt + 1)
    end
  end

  defp check_images_and_create_hls(images, state) do
    source_path = "#{@root_dir}/#{state.config.camera_exid}/timelapse/#{state.name}/images/#{images - 1}.jpg"
    loop_list(source_path)
  end

  defp create_hls(state) do
    timelapse_path = "#{@root_dir}/#{state.config.camera_exid}/timelapse/#{state.name}/"
    Porcelain.shell("bash #{timelapse_path}build.sh", [err: :out]).out
    update_timelapse_info(state)
    clean_images(state)
    # if (update_info)
    # {
    #     TimelapseVideoInfo info = UpdateVideoInfo("");
    # }
    state
  end

  def loop_list(source_path, index) do
    # File.copy()
    # download_snapshot(snap, camera_exid, path, index)
    # loop_list(path, index + 1)
  end
  def loop_list([], _camera_exid, _path, _index), do: :noop

  defp create_new_video_chunk(bashFile, start_number)
            string[] maxres = MAX_RES.Split(new char[] { ',' });
            CreateBashFile(bashFile, timelapse.FPS, timelapse.SnapsInterval, Program.DownPath, Program.TsPath, start_number);
            RunBash(bashFile);
            updateMenifiest(Program.TsPath, "low", chunkIndex[0]);
            updateMenifiest(Program.TsPath, "medium", chunkIndex[1]);
            updateMenifiest(Program.TsPath, "high", chunkIndex[2]);
            chunkIndex[0] = chunkIndex[0] + 1;
            chunkIndex[1] = chunkIndex[1] + 1;
            chunkIndex[2] = chunkIndex[2] + 1;
            TimelapseVideoInfo info = UpdateVideoInfo("");
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

  defp update_timelapse_info(state) do
    timelapse = Timelapse.by_exid("#{state.name}")
    params = %{
      resolution: "",
      snapshot_count: timelapse.snapshot_count + 24
    }
    changeset = Timelapse.update_timelapse(timelapse, params)
  end

  defp clean_images(state) do
    images_path = "#{@root_dir}/#{state.config.camera_exid}/timelapse/#{state.name}/images/"
    File.rm_rf!(images_path)
    File.mkdir_p(images_path)
    state
  end
end
