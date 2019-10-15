defmodule SQNS.Pipeline.DataTest do
  use ExUnit.Case
  alias SQNS.Pipeline.Data

  describe "extract/1" do
    setup context do
      {:ok, actual: Data.extract(context.data)}
    end

    @tag data:
           ~s[{"Message":{"data":"test"},"MessageAttributes":{"attribute":{"Type":"StringValue","Value":"val"}}}],
         expected: {%{data: "test"}, %{attribute: "val"}}
    test "sqs json", %{expected: expected, actual: actual} do
      assert expected == actual
    end

    @tag data:
           ~s[{"Message":"test","MessageAttributes":{"attribute":{"Type":"StringValue","Value":"val"}}}],
         expected: {"test", %{attribute: "val"}}
    test "sqs text", %{expected: expected, actual: actual} do
      assert expected == actual
    end

    @tag data: ~S[{"key1": "value1", "key2": "value2"}],
         expected: {%{key1: "value1", key2: "value2"}, %{}}
    test "plain json", %{expected: expected, actual: actual} do
      assert expected == actual
    end

    @tag data: ~S[plain message],
         expected: {"plain message", %{}}
    test "plain text", %{expected: expected, actual: actual} do
      assert expected == actual
    end
  end

  describe "update/2" do
    test "update message" do
      result =
        {:ok, %{data: "test"}, %{attribute: "val"}}
        |> Data.update(__MODULE__)

      assert result ==
               {
                 :ok,
                 ~S[{"data":"test"}],
                 [
                   %{data_type: :string, name: :attribute, value: {:string, "val"}},
                   %{data_type: :string, name: :process, value: {:string, "DataTest"}},
                   %{data_type: :string, name: :status, value: {:string, :ok}}
                 ]
               }
    end
  end
end
