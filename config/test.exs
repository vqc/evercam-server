use Mix.Config

config :evercam_media,
  skip_camera_workers: true

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :evercam_media, EvercamMedia.Endpoint,
  http: [port: 4001],
  server: false,
  email: "evercam.io <env.test@evercam.io>"

# Print only warnings and errors during test
config :logger, level: :warn

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

config :evercam_media, mailgun_config: [
    domain: "some_domain",
    key: "some_key",
    mode: :test,
    test_file_path: "/tmp/mailgun_test.json"
  ]
