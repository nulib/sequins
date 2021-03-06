defmodule Sequins.PipelineCase do
  @moduledoc ~S"""
  This module defines the setup for tests involving
  pipelines and actions.

  To set up queues and subscriptions for a test, use the
  `pipeline` tag, e.g.:

      @tag pipeline: [
        "queue-1": [error: "queue-3"],
        "queue-2": [ok: "queue-1", error: "queue-3"],
        "queue-3"
      ]

  The above example creates the SQS queues and SNS topics required to support 3 actions.
  It also sets up subscriptions so that `queue-1` will receive `:ok` results from `queue-2`,
  and `queue-3` will receive `:error` results from both `queue-1` and `queue-2`.
  """

  use ExUnit.CaseTemplate
  alias Sequins.Pipeline.Data

  @passthru "receiver"

  setup context do
    %{body: %{queue_url: queue_url}} = ExAws.SQS.create_queue(@passthru) |> ExAws.request!()

    with {_queues, topics, _subscriptions} <- context |> Map.get(:pipeline, []) |> Sequins.setup() do
      topics
      |> Enum.each(fn topic ->
        Sequins.Subscriptions.create_subscription({@passthru, topic, nil})
      end)
    end

    receiver_listener = Task.async(Sequins.PipelineCase, :listen, [self()])

    on_exit(fn ->
      send(receiver_listener.pid, :shutdown)
      flush(self())

      Sequins.Topics.delete_topics(Sequins.prefix())
      Sequins.Queues.delete_queues(Sequins.prefix())

      Sequins.Queues.delete_queue(@passthru)
    end)

    {
      :ok,
      %{receiver: queue_url}
    }
  end

  @doc false
  def listen(pid) do
    pass_messages(pid)

    receive do
      :shutdown -> flush(pid)
    after
      250 -> listen(pid)
    end
  end

  defp pass_messages(pid) do
    queue_url = Sequins.Queues.get_queue_url(@passthru)

    case ExAws.SQS.receive_message(queue_url) |> ExAws.request!() do
      %{body: %{messages: []}} ->
        :ok

      %{body: %{messages: messages}} ->
        messages
        |> Enum.each(fn %{body: body, receipt_handle: handle} ->
          pass_message(body, pid)

          ExAws.SQS.delete_message(queue_url, handle)
          |> ExAws.request!()
        end)

        :more
    end
  end

  defp pass_message(body, pid) do
    {msg, attrs} = Data.extract(body)
    now = System.monotonic_time(:millisecond)
    elapsed = now - Map.get(msg, :started)

    msg =
      msg
      |> Map.put_new(:finished, now)
      |> Map.put_new(:elapsed, elapsed)

    send(pid, {msg, attrs})
  end

  defp flush(pid) do
    case pass_messages(pid) do
      :more -> flush(pid)
      :ok -> :ok
    end
  end
end
