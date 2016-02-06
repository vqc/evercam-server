defmodule EvercamMedia.Snapshot.StorageSupervisor do
  use Supervisor
  alias EvercamMedia.Snapshot.Storage

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    pool_opts = [
      name: {:local, StoragePool},
      worker_module: Storage,
      size: 5,
      max_overflow: 0
    ]

    children = [
      :poolboy.child_spec(Storage, pool_opts, []),
    ]
    supervise(children, strategy: :one_for_one)
  end
end
