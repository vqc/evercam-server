defmodule EvercamMedia.Snapmail.SnapmailerSupervisor do
  @moduledoc """
  Provides function to manage snapmail workers
  """

  use Supervisor
  require Logger

  @event_handlers [
    EvercamMedia.Snapmail.PollHandler,
    EvercamMedia.Snapmail.StorageHandler
  ]

  def start_link() do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    Task.start_link(&initiate_workers/0)
    children = [worker(EvercamMedia.Snapmail.Snapmailer, [], restart: :permanent)]
    supervise(children, strategy: :simple_one_for_one, max_restarts: 1_000_000)
  end

  @doc """
  Start Snapmail worker
  """
  def start_snapmailer(nil), do: :noop
  def start_snapmailer(snapmail) do
    case get_config(snapmail) do
      {:ok, settings} ->
        Logger.debug "[#{settings.name}] Starting snapmail worker"
        Supervisor.start_child(__MODULE__, [settings])
      {:error, _message, url} ->
        Logger.warn "[#{snapmail.exid}] Skipping snapmail worker as the host is invalid: #{url}"
    end
  end

  @doc """
  Start a worker for each snapmail in the database.

  This function is intended to be called after the EvercamMedia.Snapmail.SnapmailerSupervisor
  is initiated.
  """
  def initiate_workers do
    Logger.info "Initiate workers for snapmail."
    Snapmail.all |> Enum.map(&(start_snapmailer &1))
  end

  @doc """
  Given a snapmail, it returns a map of values required for starting a snapmail worker.
  """
  def get_config(snapmail) do
    {
      :ok,
      %{
        event_handlers: @event_handlers,
        name: snapmail.exid |> String.to_atom,
        config: %{
          snapmail_id: snapmail.id,
          subject: snapmail.subject,
          recipients: snapmail.recipients,
          message: snapmail.message,
          days: Snapmail.get_days_list(snapmail.notify_days),
          notify_time: snapmail.notify_time,
          timezone: get_timezone(snapmail.snapmail_cameras),
          sleep: Snapmail.sleep(snapmail.notify_time, get_timezone(snapmail.snapmail_cameras)),
          cameras: get_lists(snapmail.snapmail_cameras)
        }
      }
    }
  end

  def get_lists([]), do: []
  def get_lists(snapmail_cameras) do
    snapmail_cameras
    |> Enum.map(fn(snapmail_camera) -> snapmail_camera.camera end)
    |> Enum.map(fn(camera) ->
      %{
        camera_exid: camera.exid,
        name: camera.name,
        url: Camera.snapshot_url(camera),
        auth: Camera.auth(camera),
        timezone: Camera.get_timezone(camera),
        vendor_exid: Camera.get_vendor_attr(camera, :exid)
      }
    end)
  end

  def get_timezone([]), do: "Etc/UTC"
  def get_timezone(snapmail_cameras) do
    camera =
      snapmail_cameras
      |> Enum.map(fn(snapmail_camera) -> snapmail_camera.camera end)
      |> List.first
    case camera.timezone do
      nil -> "Etc/UTC"
      timezone -> timezone
    end
  end
end
