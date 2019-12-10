# Sequins

[![CircleCI](https://circleci.com/gh/nulib/sequins.svg?style=svg)](https://circleci.com/gh/nulib/sequins)
[![Coverage Status](https://coveralls.io/repos/github/nulib/sequins/badge.svg?branch=master)](https://coveralls.io/github/nulib/sequins?branch=master)

An AWS SQS <-> SNS data processing pipeline built on [Broadway](https://hexdocs.pm/broadway/).

Implementation and configuration details can be found in the module and function documentation for `Sequins`, `Sequins.Pipeline`, 
and `Sequins.Pipeline.Action`.

## Installation

```elixir
def deps do
  [
    {:sequins, "~> 0.5.0"}
  ]
end
```
