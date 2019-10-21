# Sequins

[![CircleCI](https://circleci.com/gh/nulib/sequins.svg?style=svg)](https://circleci.com/gh/nulib/sequins)
[![Coverage Status](https://coveralls.io/repos/github/nulib/sequins/badge.svg?branch=master)](https://coveralls.io/github/nulib/sequins?branch=master)

An AWS SQS <-> SNS data processing pipeline for Broadway. See the module documentation for
`Sequins.Pipeline.Action` for implementation details.

## Installation

```elixir
def deps do
  [
    {:sequins, git: "https://github.com/nulib/sequins.git"}
  ]
end
```
