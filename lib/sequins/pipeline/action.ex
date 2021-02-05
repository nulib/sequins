defmodule Sequins.Pipeline.Action do
  @moduledoc ~S"""
  `Sequins.Pipeline.Action` wraps a [`Broadway SQS`](https://hexdocs.pm/broadway/amazon-sqs.html)
  processing pipeline to allow for the simple creation of multi-stage `SQS -> Broadway -> SNS`
  pipelines.

  ## Getting Started

  First, follow the [Create a SQS queue](https://hexdocs.pm/broadway/amazon-sqs.html#create-a-sqs-queue)
  and [Configure the project](https://hexdocs.pm/broadway/amazon-sqs.html#configure-the-project)
  sections of the Broadway Amazon SQS guide.

  Also make sure `config.exs` contains a valid [`ExAws`](https://hexdocs.pm/ex_aws/) configuration.

  ## Implement the processing callback

  This is where we depart from Broadway's default implementation. Pipeline.Action makes several
  opinionated assumptions about the AWS environment as well as the shape of the incoming
  message data.

  ### Processor

  `Sequins.Pipeline.Action` does some pre- and post-processing of the `Broadway.Message`
  struct. Instead of implementing `handle_message/3`, we're just going to implement
  our own `process/2`, which recieves two parameters:

    * `data`: The Message field of the incoming SQS message
    * `attrs`: The MessageAttributes field of the incoming SQS message

  `attrs` (and `data`, if it's a map) is converted from `"CamelCaseStringKeys"` to
  `:underscore_atom_keys` before being passed to `process/2`.

  `process/2`'s return value should be one of the following:

    * `{status, data, attrs}` (if both `data` and `attrs` have been updated)
    * `{status, data}` (if `data` has been updated)
    * `{status}` or `status` (if no data/attribute updates are needed)

  The `status` will be added to the `attrs` of the next message in the pipeline.

  Example:

      defmodule MyApplication.MyPipeline do
        use Pipeline.Action

        def process(data, attrs) do
          {:ok,
            data
            |> Map.get_and_update!(:value, fn n -> n * n end)}
        end
      end

  By default, the queue and topic names are imputed based on the last segment
  of the using module name (e.g., `sequins-my-pipeline` for a module ending in
  `MyPipeline`). This can be overridden by passing a `:queue_name` option to
  `use`:

      defmodule MyApplication.MyPipeline do
        use Pipeline.Action, queue_name: "my_pipeline"
        ...
      end

  The default resource prefix is `sequins`, but can be changed by configuring the
  `:sequins` application's `:prefix` attribute.

  ### Batcher

  `Sequins.Pipeline.Action` sends processed data to an [AWS Simple Notification Service](https://aws.amazon.com/sns/)
  topic, allowing it to be dispatched to another queue (and into another `Sequins.Pipeline.Action`),
  an AWS Lambda, an arbitrary webhook, or even an email or SMS message.

  ## Configuration Options

  `Sequins.Pipeline.Action` attempts to use sane defaults, inheriting most of them from `Broadway` itself.
  However, several can be overriden in the application configuration.

  ### Options

  `Sequins.Pipeline.Action` is configured by passing options to `start_link`.
  Valid options are:

    * `:producer_concurrency` - Optional. The number of producer concurrency to
      be created by Broadway. Analogous to Broadway's producer `:concurrency`
      option. Default value is 1.

    * `:receive_interval` - Optional. The frequency with which the produer
      polls SQS for new messages. Default value is 5000.

    * `:wait_time_seconds` - Optional. The duration (in seconds) for which the
      producer's ReceiveMessages call waits for a message to arrive in the queue
      before returning. Default value is 0 (short polling).

    * `:max_number_of_messages` - Optional. The maximum number of messages the
      producer requests from SQS at once. Default value is 10. Maximum value
      is 10.

    * `:visibility_timeout` - Optional. The amount of time (in seconds) SQS will
      wait for a message to be acknowledged before putting it back in the queue.
      Defaults to the queue's configured `VisibilityTimeout` setting.

    * `:processor_concurrency` - Optional. The number of processor concurrency to
      be created by Broadway. Analogous to Broadway's producer `:concurrency`
      option. Default value is 1.

    * `:max_demand` - Optional. Set the maximum demand of all processors
      concurrency. Analogous to Broadway's processor `:max_demand` option.
      Default value is 10.

    * `:min_demand` - Optional. Set the minimum demand of all processors
      concurrency. Analogous to Broadway's processor `:min_demand` option.
      Default value is 5.

    * `:batcher_concurrency` - Optional. The number of batcher concurrency to
      be created by Broadway. Analogous to Broadway's batcher `:concurrency`
      option. Default value is 1.

    * `:batch_size` - Optional. The size of generated batches. Analogous to
      Broadway's batcher `:batch_size` option. Default value is `100`.

    * `:batch_timeout` - Optional. The time, in milliseconds, that the
      batcher waits before flushing the list of messages. Analogous to
      Broadway's batcher `:batch_timeout` option. Default value is `1000`.
  """

  use Broadway
  alias Broadway.Message
  alias Sequins.Pipeline.Data
  require Logger

  @type action_option ::
          {:batch_size, pos_integer()}
          | {:batch_timeout, non_neg_integer()}
          | {:batcher_concurrency, non_neg_integer()}
          | {:max_demand, non_neg_integer()}
          | {:min_demand, non_neg_integer()}
          | {:processor_concurrency, non_neg_integer()}
          | {:producer_concurrency, non_neg_integer()}
          | {:receive_interval, non_neg_integer()}
          | {:queue_name, String.t()}
  @type action_options :: list(action_option())

  @callback process(data :: any(), attrs :: map()) ::
              {atom(), any(), map()} | {atom(), any()} | {atom()} | atom()

  defmacro __using__(use_opts) do
    mod = __CALLER__.module

    use_opts =
      case use_opts[:queue_name] do
        nil ->
          queue =
            mod
            |> Module.split()
            |> List.last()
            |> Sequins.inflect()

          use_opts |> Keyword.put_new(:queue_name, queue)

        _ ->
          use_opts
      end

    Module.register_attribute(mod, :actiondoc, accumulate: false, persist: true)
    Module.put_attribute(mod, :actiondoc, mod |> Module.split() |> List.last())

    quote location: :keep,
          bind_quoted: [queue: use_opts[:queue_name], module: mod] do
      alias Sequins.Pipeline
      require Logger

      @behaviour Pipeline.Action

      @doc false
      def child_spec(arg) do
        default = %{
          id: unquote(module),
          start: {__MODULE__, :start_link, [arg]},
          shutdown: :infinity
        }

        Supervisor.child_spec(default, [])
      end

      @doc false
      def start_link(opts) do
        Pipeline.Action.start_link(
          __MODULE__,
          opts |> Keyword.put_new(:queue_name, unquote(queue))
        )
      end

      @doc "Send a message directly to the Action's queue"
      def send_message(data, context \\ %{}) do
        unquote(queue)
        |> Sequins.Queues.get_queue_url()
        |> ExAws.SQS.send_message(
          %{
            "Message" => data,
            "MessageAttributes" =>
              context
              |> Enum.map(fn {name, value} ->
                {name, %{"Type" => "StringValue", "Value" => value}}
              end)
              |> Enum.into(%{})
          }
          |> Jason.encode!()
        )
        |> ExAws.request!()
      end

      def actiondoc do
        case __MODULE__.__info__(:attributes) |> Keyword.get(:actiondoc, nil) do
          x when is_list(x) -> List.first(x)
          x -> x
        end
      end

      def queue_name do
        unquote(queue)
      end
    end
  end

  @spec start_link(module :: module(), opts :: action_options()) :: {:ok, pid()}
  def start_link(module, opts) do
    opts = validate_config(opts)

    Broadway.start_link(
      __MODULE__,
      name: module,
      producer: [
        module: {BroadwaySQS.Producer, producer_opts(opts)},
        concurrency: opts[:producer_concurrency]
      ],
      processors: processor_opts(opts),
      batchers: batcher_opts(opts),
      context: %{
        module: module,
        queue_name: opts[:queue_name]
      }
    )
  end

  defp producer_opts(opts) do
    opts
    |> Keyword.take([
      :queue_url,
      :max_number_of_messages,
      :receive_interval,
      :visibility_timeout,
      :wait_time_seconds
    ])
    |> reject_nil_values()
  end

  defp processor_opts(opts) do
    [
      default:
        [
          concurrency: opts[:processor_concurrency],
          min_demand: opts[:min_demand],
          max_demand: opts[:max_demand]
        ]
        |> reject_nil_values()
    ]
  end

  defp batcher_opts(opts) do
    [
      sns:
        [
          concurrency: opts[:batcher_concurrency],
          batch_size: opts[:batch_size],
          batch_timeout: opts[:batch_timeout]
        ]
        |> reject_nil_values()
    ]
  end

  defp reject_nil_values(opts), do: Enum.reject(opts, fn {_, v} -> is_nil(v) end)

  @impl true
  def handle_message(_, message, %{module: module}) do
    message
    |> Message.update_data(&process_message(&1, module))
    |> Message.put_batcher(:sns)
  end

  defp process_message(message_data, module) do
    with {data, attrs} <- Data.extract(message_data) do
      with old_action <- Logger.metadata()[:action] do
        try do
          Logger.metadata(action: module |> Module.split() |> List.last())

          case module.process(data, attrs) do
            {s, d, a} -> {s, d, a}
            {s, d} -> {s, d, attrs}
            {s} -> {s, data, attrs}
            s -> {s, data, attrs}
          end
          |> Data.update(module)
        after
          Logger.metadata(action: old_action)
        end
      end
    end
  end

  @impl true
  def handle_batch(:sns, messages, _, %{queue_name: queue_name}) do
    messages
    |> Enum.each(fn %Message{data: {_, data, attrs}} ->
      topic_arn = queue_name |> Sequins.Topics.get_topic_arn()

      data
      |> ExAws.SNS.publish(topic_arn: topic_arn, message_attributes: attrs)
      |> ExAws.request!()
    end)

    messages
  end

  defp validate_config(opts) do
    zero_visibility = fn {k, v} -> k == :visibility_timeout && v == 0 end

    case opts |> Broadway.Options.validate(configuration_spec()) do
      {:error, err} ->
        raise %ArgumentError{message: err}

      {:ok, validated} ->
        case validated[:queue_name] do
          x when not is_binary(x) ->
            raise %ArgumentError{message: "expected :queue_name to be a binary, got: #{x}"}

          _ ->
            validated
            |> Keyword.put(:queue_url, Sequins.Queues.get_queue_url(validated[:queue_name]))
            |> Enum.reject(zero_visibility)
        end
    end
  end

  defp configuration_spec do
    [
      batch_size: [type: :pos_integer, default: 100],
      batch_timeout: [type: :pos_integer, default: 1000],
      batcher_concurrency: [type: :non_neg_integer, default: 1],
      max_demand: [type: :non_neg_integer, default: 10],
      max_number_of_messages: [type: :non_neg_integer, default: 10],
      min_demand: [type: :non_neg_integer, default: 5],
      processor_concurrency: [type: :non_neg_integer, default: System.schedulers_online() * 2],
      producer_concurrency: [type: :non_neg_integer, default: 1],
      receive_interval: [type: :non_neg_integer, default: 5000],
      visibility_timeout: [type: :non_neg_integer, default: 0],
      wait_time_seconds: [type: :non_neg_integer, default: 0],
      queue_name: [required: true, type: :any]
    ]
  end
end
