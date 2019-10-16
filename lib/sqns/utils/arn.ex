defmodule SQNS.Utils.Arn do
  @moduledoc """
  Utilities for parsing and manipulating AWS ARNs
  """

  @type update_function :: (String.t() -> String.t())
  @type new_value :: nil | String.t() | update_function()

  defstruct scheme: "arn",
            partition: "aws",
            service: nil,
            region: "",
            account: "",
            resource: ""

  @doc "Parse an ARN into a struct"
  def parse(arn) do
    values =
      [:scheme, :partition, :service, :region, :account, :resource]
      |> Enum.zip(String.split(arn, ":", parts: 6))

    struct(__MODULE__, values)
  end

  @doc "Update the ARN scheme"
  @spec update_scheme(arn :: __MODULE__, v :: new_value()) :: __MODULE__
  def update_scheme(arn, v), do: update_x(arn, :scheme, v)

  @doc "Update the ARN partition"
  @spec update_partition(arn :: __MODULE__, v :: new_value()) :: __MODULE__
  def update_partition(arn, v), do: update_x(arn, :partition, v)

  @doc "Update the ARN service"
  @spec update_service(arn :: __MODULE__, v :: new_value()) :: __MODULE__
  def update_service(arn, v), do: update_x(arn, :service, v)

  @doc "Update the ARN region"
  @spec update_region(arn :: __MODULE__, v :: new_value()) :: __MODULE__
  def update_region(arn, v), do: update_x(arn, :region, v)

  @doc "Update the ARN account"
  @spec update_account(arn :: __MODULE__, v :: new_value()) :: __MODULE__
  def update_account(arn, v), do: update_x(arn, :account, v)

  @doc "Update the ARN resource"
  @spec update_resource(arn :: __MODULE__, v :: new_value()) :: __MODULE__
  def update_resource(arn, v), do: update_x(arn, :resource, v)

  @doc "Convert an ARN struct to a string"
  @spec to_string(arn :: __MODULE__) :: String.t()
  def to_string(arn) do
    [arn.scheme, arn.partition, arn.service, arn.region, arn.account, arn.resource]
    |> Enum.join(":")
  end

  defp update_x(arn, x, f) when is_function(f), do: update_x(arn, x, f.(arn |> Map.get(x)))

  defp update_x(arn, x, v),
    do: struct!(__MODULE__, arn |> Map.from_struct() |> Map.put(x, v) |> Enum.into([]))
end
