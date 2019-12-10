defmodule Sequins do
  alias Sequins.{Queues, Subscriptions, Topics}
  use Application
  require Logger

  @moduledoc """
  Utilities to create the queues, topics, and subscriptions required to
  support the ingest pipeline.
  """

  @type stringish :: atom() | binary()
  @type filter :: {stringish(), stringish()}
  @type subscription :: stringish() | {stringish(), list(filter())}
  @type subscriptions :: list(subscription())
  @type spec :: stringish() | {stringish(), subscriptions()}
  @type specs :: list(spec)

  @doc """
  Set up pipeline infrastructure based on a list of queue/topic/subscription specs. A spec
  looks like this:

      {Action, [{OtherAction, [filters]}, ...]}

  An action with no subscriptions can simply be specified as

      Action

  For example, let's say you have 4 actions – `A` (do some things), `B` & `C` (do some things; depend
  on A's success), and `D` (handles all errors). The spec for this would be:

      [
        :A,
        B: [A: [status: :ok]],
        C: [A: [status: :ok]],
        D: [A: [status: :error], B: [status: :error], C: [status: :error]]
      ]

  The above spec will create:

  * 4 SQS queues (`sequins-a`, `sequins-c`, `sequins-c`, `sequins-d`)
  * 4 SNS topics (`sequins-a`, `sequins-c`, `sequins-c`, `sequins-d`)
  * 5 SNS subscriptions
    * `sequins-a` -> `sequins-b` ({"status": "ok"})
    * `sequins-a` -> `sequins-c` ({"status": "ok"})
    * `sequins-a` -> `sequins-d` ({"status": "error"})
    * `sequins-b` -> `sequins-d` ({"status": "error"})
    * `sequins-c` -> `sequins-d` ({"status": "error"})

  The spec can also be defined by setting up a `Sequins.Pipeline` and configuring it.

      # my_pipeline.exs

      defmodule MyPipeline do
        use Sequins.Pipeline
      end

      # config.exs

      config :sequins, MyPipeline, actions: [A, B, C, D]
      config :sequins, B, [A: [status: :ok]]
      config :sequins, C, [A: [status: :ok]]
      config :sequins, D, [A: [status: :error], B: [status: :error], C: [status: :error]]

      # then, to set up SQS/SNS for this pipeline:

      Sequins.setup(MyPipeline.queue_config())

  The default prefix for created resources is `sequins`, but can be changed by configuring
  the `:sequins` application's `:prefix` attribute.

  In addition to `:status`, subscriptions can filter on any attribute added to the `attrs` hash
  by the `Sequins.Pipeline.Action.process/2` callback.
  """
  @spec setup(specs :: specs()) :: {list(), list(), list()}
  def setup(specs) do
    (queues = parse_queues(specs)) |> Queues.create_queues()
    (topics = parse_topics(specs)) |> Topics.create_topics()
    Subscriptions.delete_subscriptions(prefix())
    (subscriptions = parse_subscriptions(specs)) |> Subscriptions.create_subscriptions()
    {queues, topics, subscriptions}
  end

  def inflect(value) do
    if is_atom(value) &&
         Code.ensure_loaded?(value) &&
         function_exported?(value, :queue_name, 0),
       do: value.queue_name(),
       else:
         [
           prefix(),
           value
           |> to_string()
           |> Inflex.underscore()
           |> String.replace("_", "-")
         ]
         |> Enum.reject(&is_nil/1)
         |> Enum.join("")
  end

  def parse_queues(specs) do
    specs
    |> Enum.map(fn
      {queue, _} -> inflect(queue)
      queue -> inflect(queue)
    end)
  end

  def parse_topics(specs), do: parse_queues(specs)

  def parse_filters(filters) do
    filters
    |> Enum.map(fn
      {key, value} when is_list(value) -> {key, value}
      {key, value} -> {key, [value]}
    end)
    |> Enum.into(%{})
  end

  def parse_subscriptions(specs) do
    specs
    |> Enum.filter(fn
      {_, _} -> true
      _ -> false
    end)
    |> Enum.map(fn {queue, queue_subs} ->
      queue_subs
      |> Enum.map(fn
        {target, filters} ->
          {inflect(queue), inflect(target), filters |> parse_filters()}

        target ->
          {inflect(queue), inflect(target), nil}
      end)
    end)
    |> List.flatten()
  end

  @doc false
  @impl Application
  def start(_type, _args) do
    Supervisor.start_link([], name: __MODULE__.Supervisor, strategy: :one_for_one)
  end

  def start_children(children) do
    Enum.map(children, &start_child/1)
  end

  defp start_child(action) do
    child_name =
      case action do
        {mod, _} -> to_string(mod)
        mod -> to_string(mod)
      end

    Logger.info("Sequins: Starting #{child_name}")

    case Supervisor.start_child(__MODULE__.Supervisor, action) do
      {:ok, pid} ->
        {:ok, action, pid}

      {:error, reason} ->
        message =
          case reason do
            {{:EXIT, {err, _}}, _} -> inspect(err)
            err -> inspect(err)
          end

        Logger.warn("Sequins: #{child_name} failed to start: #{message}")
        {:error, action, reason}
    end
  end

  def prefix do
    Application.get_env(:sequins, :prefix, "sequins") <> "-"
  end
end
