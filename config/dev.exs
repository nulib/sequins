use Mix.Config

config :ex_aws,
  access_key_id: "fake",
  secret_access_key: "fake"

config :ex_aws, :sqs,
  host: "localhost",
  port: 4101,
  scheme: "http://",
  region: "us-east-1"

config :ex_aws, :sns,
  host: "localhost",
  port: 4101,
  scheme: "http://",
  region: "us-east-1"

# Do not include metadata nor timestamps in development logs
config :logger, :console,
  format: "$metadata[$level] $levelpad$message\n",
  metadata: [:action]
