defmodule Sequins.TestCase do
  use ExUnit.CaseTemplate

  @moduledoc """
  Test case for testing Sequins resources
  """

  using do
    quote do
      setup do
        on_exit(fn ->
          Sequins.Topics.delete_topics(Sequins.prefix())
          Sequins.Queues.delete_queues(Sequins.prefix())
        end)

        :ok
      end
    end
  end
end
