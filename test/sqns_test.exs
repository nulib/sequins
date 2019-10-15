defmodule SQNSTest do
  use SQNS.TestCase
  import ExUnit.CaptureLog

  describe "queues" do
    test "create missing queue" do
      assert(
        capture_log(fn ->
          assert(
            SQNS.Queues.create_queue("sqns-test-queue") ==
              "http://sqs.us-east-1.goaws.com:4100/100010001000/sqns-test-queue"
          )
        end) =~ "Creating Queue: sqns-test-queue"
      )
    end

    test "create existing queue" do
      SQNS.Queues.create_queue("sqns-test-queue")

      assert(
        capture_log(fn ->
          assert(SQNS.Queues.create_queue("sqns-test-queue") == :noop)
        end) =~ "Queue sqns-test-queue already exists"
      )
    end
  end

  describe "topics" do
    test "create missing topic" do
      assert(
        capture_log(fn ->
          assert(
            SQNS.Topics.create_topic("sqns-test-topic") ==
              "arn:aws:sns:us-east-1:100010001000:sqns-test-topic"
          )
        end) =~ "Creating Topic: sqns-test-topic"
      )
    end

    test "create existing topic" do
      SQNS.Topics.create_topic("sqns-test-topic")

      assert(
        capture_log(fn ->
          assert(SQNS.Topics.create_topic("sqns-test-topic") == :noop)
        end) =~ "Topic sqns-test-topic already exists"
      )
    end
  end

  describe "subscriptions" do
    setup do
      SQNS.Queues.create_queue("sqns-test-queue")
      SQNS.Topics.create_topic("sqns-test-topic")
      :ok
    end

    test "create missing subscription" do
      assert(
        capture_log(fn ->
          assert(
            SQNS.Subscriptions.create_subscription({"sqns-test-queue", "sqns-test-topic", nil}) ==
              {"arn:aws:sns:us-east-1:100010001000:sqns-test-topic",
               "arn:aws:sqs:us-east-1:100010001000:sqns-test-queue", %{}}
          )
        end) =~ "Creating Subscription: sqns-test-topic → sqns-test-queue"
      )
    end

    test "create existing subscription" do
      SQNS.Subscriptions.create_subscription({"sqns-test-queue", "sqns-test-topic", nil})

      assert(
        capture_log(fn ->
          assert(
            SQNS.Subscriptions.create_subscription({"sqns-test-queue", "sqns-test-topic", nil}) ==
              :noop
          )
        end) =~ "Subscription sqns-test-topic → sqns-test-queue already exists"
      )
    end

    test "delete subscriptions" do
      SQNS.Subscriptions.create_subscription({"sqns-test-queue", "sqns-test-topic", nil})
      assert(SQNS.Subscriptions.list_subscriptions("sqns-test-") |> length() == 1)
      SQNS.Subscriptions.delete_subscriptions("sqns-test-")
      assert(SQNS.Subscriptions.list_subscriptions("sqns-test-") |> length() == 0)
    end
  end

  describe "specs" do
    test "create all queues, topics, and subscriptions based on a spec" do
      SQNS.setup([
        :a,
        b: [a: [status: :ok]],
        c: [:a, :b]
      ])

      expected_queues = ~w(sqns-test-a sqns-test-b sqns-test-c)
      expected_topics = ~w(sqns-test-a sqns-test-b sqns-test-c)

      expected_subscriptions = [
        {"sqns-test-a", "sqns-test-c", %{}},
        {"sqns-test-b", "sqns-test-c", %{}},
        {"sqns-test-a", "sqns-test-b", %{"status" => ["ok"]}}
      ]

      with actual_queues <- SQNS.Queues.list_queue_names(SQNS.prefix()) |> Enum.sort() do
        assert(actual_queues == expected_queues)
      end

      with actual_topics <- SQNS.Topics.list_topic_names(SQNS.prefix()) |> Enum.sort() do
        assert(actual_topics == expected_topics)
      end

      with actual_subscriptions <- SQNS.Subscriptions.list_subscriptions(SQNS.prefix()) do
        assert(
          expected_subscriptions
          |> Enum.all?(fn sub -> sub in actual_subscriptions end)
        )

        assert(actual_subscriptions -- expected_subscriptions == [])
      end
    end
  end
end
