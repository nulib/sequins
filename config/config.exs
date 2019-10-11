# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $levelpad$message\n",
  metadata: [:request_id, :action]

config :sqns, prefix: "sqns"

aws_env =
  System.get_env(
    "AWS_PROFILE",
    System.get_env("AWS_DEFAULT_PROFILE", "default")
  )

aws_region =
  System.get_env(
    "AWS_REGION",
    System.get_env("AWS_DEFAULT_REGION", "us-east-1")
  )

config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, {:awscli, aws_env, 30}, :instance_role],
  secret_access_key: [
    {:system, "AWS_SECRET_ACCESS_KEY"},
    {:awscli, aws_env, 30},
    :instance_role
  ],
  region: aws_region

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
