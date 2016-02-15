use Mix.Config

config :evercam_media,
  start_camera_workers: false

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :evercam_media, EvercamMedia.Endpoint,
  http: [port: 4001],
  server: false,
  email: "evercam.io <env.test@evercam.io>"

# Print only warnings and errors during test
config :logger, level: :warn

config :evercam_media,
  storage_dir: "tmp/storage"

# Configure your database
config :evercam_media, EvercamMedia.Repo,
  adapter: Ecto.Adapters.Postgres,
  extensions: [{EvercamMedia.Types.JSON.Extension, library: Poison}],
  username: "postgres",
  password: "postgres",
  database: "evercam_tst",
  pool: Ecto.Adapters.SQL.Sandbox

config :evercam_media, EvercamMedia.SnapshotRepo,
  adapter: Ecto.Adapters.Postgres,
  extensions: [{EvercamMedia.Types.JSON.Extension, library: Poison}],
  username: "postgres",
  password: "postgres",
  database: "evercam_tst",
  pool: Ecto.Adapters.SQL.Sandbox
