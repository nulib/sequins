# Sequins

[![Build](https://github.com/nulib/sequins/actions/workflows/build.yml/badge.svg)](https://github.com/nulib/sequins/actions/workflows/build.yml)
[![Coverage Status](https://coveralls.io/repos/github/nulib/sequins/badge.svg?branch=master)](https://coveralls.io/github/nulib/sequins?branch=master)

An AWS SQS <-> SNS data processing pipeline built on [Broadway](https://hexdocs.pm/broadway/). See the
module documentation for `Sequins.Pipeline.Action` and the function documentation for `Sequins.setup`
for implementation details.

## Installation

```elixir
def deps do
  [
    {:sequins, "~> 0.7.0"}
  ]
end
```
