use Mix.Config

# For production, we configure the host to read the PORT
# from the system environment. Therefore, you will need
# to set PORT=80 before running your server.
#
# You should also configure the url host to something
# meaningful, we use this information when generating URLs.
config :evercam_media, EvercamMedia.Endpoint,
  check_origin: false,
  http: [port: 4000],
  url: [host: "evercam.io"],
  email: "evercam.io <support@evercam.io>"

# ## SSL Support
#
# To get SSL working, you will need to add the `https` key
# to the previous section:
#
#  config:evercam_media, EvercamMedia.Endpoint,
#    ...
#    https: [port: 443,
#            keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
#            certfile: System.get_env("SOME_APP_SSL_CERT_PATH")]
#
# Where those two env variables point to a file on
# disk for the key and cert.

# Do not print debug messages in production
config :logger, level: :info

# Filter out these fields from the logs
config :phoenix, :filter_parameters, ["password", "api_key"]

# ## Using releases
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start the server for all endpoints:
#
#     config :phoenix, :serve_endpoints, true
#
# Alternatively, you can configure exactly which server to
# start per endpoint:
#
#     config :evercam_media, EvercamMedia.Endpoint, server: true
#

config :evercam_media,
  hls_url: "https://media.evercam.io"

config :exq,
  host: System.get_env("REDIS_HOST") |> String.to_char_list,
  port: System.get_env("REDIS_PORT") |> String.to_integer,
  password: System.get_env("REDIS_PASS") |> String.to_char_list,
  namespace: "sidekiq",
  queues: ["to_elixir"]

config :evercam_media, EvercamMedia.Repo,
  adapter: Ecto.Adapters.Postgres,
  extensions: [{EvercamMedia.Types.JSON.Extension, library: Poison}],
  url: System.get_env("DATABASE_URL"),
  socket_options: [keepalive: true],
  pool: Ecto.Pools.SojournBroker,
  broker: Ecto.Pools.SojournBroker.Timeout,
  timeout: 60_000,
  pool_timeout: 15_000,
  pool_size: 50,
  lazy: false,
  log_level: :info,
  ssl: true

config :evercam_media, EvercamMedia.SnapshotRepo,
  adapter: Ecto.Adapters.Postgres,
  extensions: [{EvercamMedia.Types.JSON.Extension, library: Poison}],
  url: System.get_env("SNAPSHOT_DATABASE_URL"),
  socket_options: [keepalive: true],
  pool: Ecto.Pools.SojournBroker,
  broker: Ecto.Pools.SojournBroker.Timeout,
  timeout: 60_000,
  pool_timeout: 15_000,
  pool_size: 100,
  lazy: false,
  ssl: true

# Finally import the config/prod.secret.exs
# which should be versioned separately.
import_config "prod.secret.exs"
