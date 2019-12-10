defmodule Sequins.Pipeline do
  @moduledoc """
  `Sequins.Pipeline` provides a wrapper to group actions into processing pipelines.

      # my_pipeline.ex
      defmodule MyPipeline do
        use Sequins.Pipeline
      end

      # config.exs
      config :sequins, MyPipeline,
        actions: [ActionOne, ActionTwo, ActionThree]

      config :sequins, ActionTwo,
        queue_config: [max_number_of_messages: 3, visibility_timeout: 180],
        notify_on: [ActionOne: [status: :ok]]

      # application.ex
      def start(_type, _args) do
        # Start other processes here
        MyPipeline.start()
      end
  """

  defmacro __using__(_use_opts) do
    quote location: :keep, bind_quoted: [module: __CALLER__.module] do
      def child_spec(opts) do
        %{
          id: unquote(module),
          start: {unquote(module), :start_link, [opts]},
          type: :worker,
          restart: :permanent,
          shutdown: 500
        }
      end

      def start do
        Application.ensure_started(:sequins, :permanent)
        Sequins.start_children(children())
      end

      def actions, do: Sequins.Pipeline.actions(unquote(module))
      def children, do: Sequins.Pipeline.children(unquote(module))
      def queue_config, do: Sequins.Pipeline.queue_config(unquote(module))
    end
  end

  def actions(module) do
    pipeline_actions(module)
    |> Enum.reduce([], fn action, acc ->
      case action_config(action) |> Keyword.get(:ignore) do
        true -> acc
        _ -> [action | acc]
      end
    end)
    |> Enum.reverse()
  end

  def children(module) do
    pipeline_actions(module)
    |> Enum.map(fn action ->
      {action,
       action_config(action)
       |> Keyword.get(:queue_config)}
    end)
  end

  def queue_config(module) do
    pipeline_actions(module)
    |> Enum.map(fn action ->
      {action, action_config(action) |> Keyword.get(:notify_on, [])}
    end)
  end

  defp pipeline_actions(module) do
    Application.get_env(:sequins, module, [])
    |> Keyword.get(:actions)
  end

  defp action_config(action) do
    [queue_config: [], ignore: false, notify_on: []]
    |> Keyword.merge(Application.get_env(:sequins, action, []))
  end
end
