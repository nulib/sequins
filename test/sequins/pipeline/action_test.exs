defmodule Sequins.Pipeline.ActionTest do
  use Sequins.PipelineCase

  doctest Sequins.Pipeline.Action

  @timeout 2000

  describe "action" do
    @tag pipeline: [
           :ProcessA,
           ProcessB: [ProcessA: [status: :ok, user_data: :xyz]],
           ProcessC: [ProcessA: [user_data: :bleh]],
           ProcessD: [ProcessA: [status: :ok]],
           ProcessE: [ProcessA: [status: :ok]]
         ]
    test "simple pipeline", context do
      defmodule ProcessA do
        alias Sequins.Pipeline.Action
        use Action

        def process(data, attrs) do
          {:ok, data |> Map.put(:a, "received"), attrs}
        end
      end

      defmodule ProcessB do
        alias Sequins.Pipeline.Action
        use Action

        def process(data, _) do
          {:error, data |> Map.put(:b, "received")}
        end
      end

      defmodule ProcessC do
        alias Sequins.Pipeline.Action
        use Action

        def process(data, _) do
          {:error, data |> Map.put(:c, "received")}
        end
      end

      defmodule ProcessD do
        alias Sequins.Pipeline.Action
        use Action

        def process(_, _), do: {:ok}
      end

      defmodule ProcessE do
        alias Sequins.Pipeline.Action
        use Action

        def process(_, _), do: :ok
      end

      start_supervised({ProcessA, receive_interval: 10})
      start_supervised({ProcessB, receive_interval: 10})
      start_supervised({ProcessC, receive_interval: 10})
      start_supervised({ProcessD, receive_interval: 10})
      start_supervised({ProcessE, receive_interval: 10})
      time = System.monotonic_time(:millisecond)
      ProcessA.send_message(%{started: time}, %{user_data: "xyz"})

      assert_receive(
        {%{started: ^time, a: "received"}, %{status: "ok", user_data: "xyz"}},
        @timeout
      )

      assert_receive(
        {%{started: ^time, a: "received", b: "received"}, %{status: "error", user_data: "xyz"}},
        @timeout
      )

      refute_receive(
        {%{started: ^time, a: "received", c: "received"}, %{status: "error", user_data: "bleh"}},
        @timeout
      )
    end
  end

  describe "configs" do
    test "explicit queue name" do
      assert(
        {:module, _, _, _} =
          defmodule ExplicitQueue do
            use Sequins.Pipeline.Action, queue_name: "queue-x"
            def process(_, _), do: :ok
          end
      )
    end

    test "invalid queue name" do
      defmodule InvalidQueueName do
        use Sequins.Pipeline.Action, queue_name: 'charlist'
        def process(_, _), do: :ok
      end

      assert {result, {{:EXIT, {err, _}}, _}} = start_supervised(InvalidQueueName)

      assert(result == :error)
      assert(err.message == "expected :queue_name to be a binary, got: charlist")
    end

    test "default description" do
      defmodule DefaultDescription do
        use Sequins.Pipeline.Action
        def process(_, _), do: :ok
      end

      assert DefaultDescription.actiondoc() == "DefaultDescription"
    end

    test "explicit description" do
      defmodule ExplicitDescription do
        use Sequins.Pipeline.Action
        @actiondoc "This module has an explicit description"
        def process(_, _), do: :ok
      end

      assert ExplicitDescription.actiondoc() == "This module has an explicit description"
    end
  end
end
