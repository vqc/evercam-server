# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

config :hackney,
  :timeout, 15000

# Configures the endpoint
config :evercam_media, EvercamMedia.Endpoint,
  check_origin: false,
  url: [host: "localhost"],
  secret_key_base: "joIg696gDBw3ZjdFTkuWNz7s21nXrcRUkZn3Lsdp7pCNodzCMl/KymikuJVw0igG",
  debug_errors: false,
  server: true,
  root: Path.expand("..", __DIR__),
  pubsub: [name: EvercamMedia.PubSub,
           adapter: Phoenix.PubSub.PG2]

config :evercam_media,
  mailgun_domain: System.get_env("MAILGUN_DOMAIN"),
  mailgun_key: System.get_env("MAILGUN_KEY")

config :logger, :console,
  format: "$date $time $metadata[$level] $message\n",
  metadata: [:request_id]

config :evercam_media,
  hls_url: "http://localhost:8080"

config :exq,
  host: '127.0.0.1',
  port: 6379,
  namespace: "sidekiq",
  queues: ["to_elixir"]

config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_KEY"}, :instance_role]

config :ex_aws, :s3,
  scheme: "https://",
  host: "s3-eu-west-1.amazonaws.com",
  region: "eu-west-1"

config :quantum, cron: [
  "0 * * * * EvercamMedia.Snapshot.Cleanup.init"
]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
