use Mix.Config

config :ex_aws,
  access_key_id: "minio",
  secret_access_key: "minio123"

config :ex_aws, :sqs,
  host: "localhost",
  port: if(System.get_env("CI"), do: 4100, else: 4102),
  scheme: "http://",
  region: "us-east-1"

config :ex_aws, :sns,
  access_key_id: "",
  secret_access_key: "",
  host: "localhost",
  port: if(System.get_env("CI"), do: 4100, else: 4102),
  scheme: "http://",
  region: "us-east-1"

config :sqns, prefix: "sqns-test"

# Print only warnings and errors during test
config :logger, level: :info
