ExUnit.configure(exclude: [skip: true])
ExUnit.start
Ecto.Adapters.SQL.Sandbox.mode(EvercamMedia.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(EvercamMedia.SnapshotRepo, :manual)
