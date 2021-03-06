defmodule Sequins.Topics do
  @moduledoc false

  alias ExAws.SNS
  alias Sequins.Utils.Arn
  require Logger

  def list_topics(prefix \\ "", topics \\ [], start_token \\ "") do
    with %{body: result} <- SNS.list_topics(next_token: start_token) |> ExAws.request!() do
      case Map.get(result, :next_token, "") do
        "" -> topics ++ result.topics
        token -> list_topics(topics ++ result.topics, token)
      end
    end
    |> Enum.filter(fn topic_arn ->
      topic_arn |> Arn.parse() |> Map.get(:resource) |> String.starts_with?(prefix)
    end)
  end

  def list_topic_names(prefix \\ "") do
    list_topics(prefix)
    |> Enum.map(fn topic_arn ->
      topic_arn |> Arn.parse() |> Map.get(:resource)
    end)
  end

  def create_topics(topics) do
    existing = list_topic_names()

    topics
    |> Enum.each(fn topic -> create_topic(topic, existing) end)
  end

  def create_topic(topic_name, existing) do
    case existing |> Enum.find(&(&1 == topic_name)) do
      nil ->
        Logger.info("Creating Topic: #{topic_name}")
        get_topic_arn(topic_name)

      _ ->
        Logger.info("Topic #{topic_name} already exists")
        :noop
    end
  end

  def create_topic(topic_name), do: create_topic(topic_name, list_topic_names())

  def get_topic_arn(topic_name) do
    with %{body: %{topic_arn: result}} <-
           ExAws.SNS.create_topic(topic_name) |> ExAws.request!(),
         do: result
  end

  def delete_topic(topic_name) do
    topic_name
    |> get_topic_arn
    |> ExAws.SNS.delete_topic()
    |> ExAws.request!()
  end

  def delete_topics(prefix) do
    list_topic_names(prefix)
    |> Enum.each(&delete_topic/1)
  end
end
