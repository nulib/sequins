defmodule SQNS do
  alias SQNS.{Queues, Subscriptions, Topics}
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

  @doc "Set up pipeline infrastructure based on a list of queue/topic/subscription specs"
  @spec setup(specs :: specs()) :: {list(), list(), list()}
  def setup(specs) do
    (queues = parse_queues(specs)) |> Queues.create_queues()
    (topics = parse_topics(specs)) |> Topics.create_topics()
    Subscriptions.delete_subscriptions(prefix())
    (subscriptions = parse_subscriptions(specs)) |> Subscriptions.create_subscriptions()
    {queues, topics, subscriptions}
  end

  def inflect(value) do
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

    Logger.info("SQNS: Starting #{child_name}")

    case Supervisor.start_child(__MODULE__.Supervisor, action) do
      {:ok, pid} ->
        {:ok, action, pid}

      {:error, reason} ->
        message =
          case reason do
            {{:EXIT, {err, _}}, _} -> inspect(err)
            err -> inspect(err)
          end

        Logger.warn("SQNS: #{child_name} failed to start: #{message}")
        {:error, action, reason}
    end
  end

  def prefix do
    Application.get_env(:sqns, :prefix, "sqns") <> "-"
  end
end
