defmodule SQNS.Pipeline.Data do
  @moduledoc """
  Functions for converting Broadway SQS messages into SQNS messages and preparing
  the results for SNS
  """
  @type t() :: {term(), map()}

  @doc "Extract processable data and attributes from an SQS Broadway.Message"
  def extract(data) do
    case decode(data) do
      %{message: msg, message_attributes: attrs} ->
        {decode(msg), attrs |> attrs_to_map()}

      msg ->
        {decode(msg), %{}}
    end
  end

  @doc "Assemble the return value to hand off to the SNS batcher"
  def update({status, data, attrs}, caller) do
    context_attrs = %{
      status: status,
      process: caller |> to_string() |> String.split(".") |> List.last()
    }

    {
      status,
      data |> Jason.encode!(),
      attrs |> Map.merge(context_attrs) |> map_to_attrs()
    }
  end

  @doc "Convert SQS message attributes to a map"
  def attrs_to_map(attrs) do
    attrs
    |> Enum.map(fn
      %{name: name, value: value} -> {name, value}
      {name, %{value: value}} -> {name, value}
    end)
    |> Enum.into(%{})
  end

  @doc "Convert a map to SQS message attributes"
  def map_to_attrs(map) do
    map
    |> Enum.map(fn {name, value} -> %{name: name, data_type: :string, value: {:string, value}} end)
  end

  defp decode(data) do
    case Jason.decode(data) do
      {:ok, result} -> AtomicMap.convert(result, safe: false)
      _ -> data
    end
  rescue
    ArgumentError -> data
  end
end
