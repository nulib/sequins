defmodule SQNS.TestCase do
  use ExUnit.CaseTemplate

  @moduledoc """
  Test case for testing SQNS resources
  """

  using do
    quote do
      setup do
        on_exit(fn ->
          SQNS.Topics.delete_topics(SQNS.prefix())
          SQNS.Queues.delete_queues(SQNS.prefix())
        end)

        :ok
      end
    end
  end
end
