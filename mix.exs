defmodule Sequins.MixProject do
  use Mix.Project

  @version "0.5.1"
  @url "https://github.com/nulib/sequins"

  def project do
    [
      app: :sequins,
      name: "Sequins",
      description: "An AWS SQS <-> SNS data processing pipeline built on Broadway.",
      package: package(),
      version: @version,
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.circle": :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Sequins, []},
      extra_applications: [:ex_aws, :logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:atomic_map, "~> 0.8"},
      {:broadway_sqs, "~> 0.4.0"},
      {:configparser_ex, "~> 4.0.0"},
      {:credo, "~> 1.1.1", only: [:dev, :test], runtime: false},
      {:earmark, "~> 1.2", only: [:dev, :docs]},
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.0"},
      {:ex_aws_sns, "~> 2.1.0"},
      {:ex_aws_sqs, "~> 3.0"},
      {:excoveralls, "~> 0.10", only: :test},
      {:ex_doc, "~> 0.19", only: [:dev, :docs]},
      {:hackney, "~> 1.15"},
      {:inflex, "~> 2.0.0"},
      {:jason, "~> 1.0"},
      {:mox, "~> 0.5", only: :test},
      {:poison, ">= 3.0.0"},
      {:sweet_xml, "~> 0.6"}
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      maintainers: ["Michael B. Klein"],
      links: %{GitHub: @url}
    ]
  end
end
