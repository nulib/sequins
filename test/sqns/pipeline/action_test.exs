defmodule SQNS.Pipeline.ActionTest do
  use SQNS.PipelineCase

  doctest SQNS.Pipeline.Action

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
        alias SQNS.Pipeline.Action
        use Action

        def process(data, attrs) do
          {:ok, data |> Map.put(:a, "received"), attrs}
        end
      end

      defmodule ProcessB do
        alias SQNS.Pipeline.Action
        use Action

        def process(data, _) do
          {:error, data |> Map.put(:b, "received")}
        end
      end

      defmodule ProcessC do
        alias SQNS.Pipeline.Action
        use Action

        def process(data, _) do
          {:error, data |> Map.put(:c, "received")}
        end
      end

      defmodule ProcessD do
        alias SQNS.Pipeline.Action
        use Action

        def process(_, _), do: {:ok}
      end

      defmodule ProcessE do
        alias SQNS.Pipeline.Action
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
        {%{started: ^time, a: "received"}, %{status: "ok", user_data: xyz}},
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
            use SQNS.Pipeline.Action, queue_name: "queue-x"
            def process(_, _), do: :ok
          end
      )
    end

    test "invalid queue name" do
      defmodule InvalidQueueName do
        use SQNS.Pipeline.Action, queue_name: 'charlist'
        def process(_, _), do: :ok
      end

      assert {result, {{:EXIT, {err, _}}, _}} = start_supervised(InvalidQueueName)

      assert(result == :error)
      assert(err.message == "expected :queue_name to be a binary, got: charlist")
    end

    test "invalid option" do
      defmodule InvalidOption do
        use SQNS.Pipeline.Action
        def process(_, _), do: :ok
      end

      assert {result, {{:EXIT, {err, _}}, _}} =
               start_supervised({InvalidOption, this_option_is_invalid: true})

      assert(result == :error)
      assert(err.message =~ ~r{unknown options \[:this_option_is_invalid\]})
    end
  end
end
