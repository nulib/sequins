defmodule SequinsTest do
  use Sequins.TestCase
  import ExUnit.CaptureLog

  doctest Sequins
  doctest Sequins.Queues
  doctest Sequins.Subscriptions
  doctest Sequins.Topics

  describe "queues" do
    test "create missing queue" do
      queue_name = "sequins-test-queue"

      assert(
        capture_log(fn ->
          assert Regex.match?(~r/#{queue_name}/, Sequins.Queues.create_queue(queue_name))
        end) =~ "Creating Queue: #{queue_name}"
      )
    end

    test "create existing queue" do
      Sequins.Queues.create_queue("sequins-test-queue")

      assert(
        capture_log(fn ->
          assert(Sequins.Queues.create_queue("sequins-test-queue") == :noop)
        end) =~ "Queue sequins-test-queue already exists"
      )
    end
  end

  describe "topics" do
    test "create missing topic" do
      topic_name = "sequins-test-topic"

      assert(
        capture_log(fn ->
          assert Regex.match?(~r/#{topic_name}/, Sequins.Topics.create_topic(topic_name))
        end) =~ "Creating Topic: #{topic_name}"
      )
    end

    test "create existing topic" do
      Sequins.Topics.create_topic("sequins-test-topic")

      assert(
        capture_log(fn ->
          assert(Sequins.Topics.create_topic("sequins-test-topic") == :noop)
        end) =~ "Topic sequins-test-topic already exists"
      )
    end
  end

  describe "subscriptions" do
    setup do
      Sequins.Queues.create_queue("sequins-test-queue")
      Sequins.Topics.create_topic("sequins-test-topic")
      :ok
    end

    test "create missing subscription" do
      assert(
        capture_log(fn ->
          assert {topic, queue, filter} =
                   Sequins.Subscriptions.create_subscription(
                     {"sequins-test-queue", "sequins-test-topic", nil}
                   )

          assert Regex.match?(~r/arn:aws:sns:(us-east-1)?:100010001000:sequins-test-topic/, topic)
          assert Regex.match?(~r/arn:aws:sqs:(us-east-1)?:100010001000:sequins-test-queue/, queue)
          assert filter == %{}
        end) =~ "Creating Subscription: sequins-test-topic → sequins-test-queue"
      )
    end

    test "create existing subscription" do
      Sequins.Subscriptions.create_subscription({"sequins-test-queue", "sequins-test-topic", nil})

      assert(
        capture_log(fn ->
          assert(
            Sequins.Subscriptions.create_subscription(
              {"sequins-test-queue", "sequins-test-topic", nil}
            ) ==
              :noop
          )
        end) =~ "Subscription sequins-test-topic → sequins-test-queue already exists"
      )
    end

    test "delete subscriptions" do
      Sequins.Subscriptions.create_subscription({"sequins-test-queue", "sequins-test-topic", nil})
      assert(Sequins.Subscriptions.list_subscriptions("sequins-test-") |> length() == 1)
      Sequins.Subscriptions.delete_subscriptions("sequins-test-")
      assert(Sequins.Subscriptions.list_subscriptions("sequins-test-") |> length() == 0)
    end
  end

  describe "specs" do
    test "create all queues, topics, and subscriptions based on a spec" do
      Sequins.setup([
        :a,
        b: [a: [status: :ok]],
        c: [:a, :b]
      ])

      expected_queues = ~w(sequins-test-a sequins-test-b sequins-test-c)
      expected_topics = ~w(sequins-test-a sequins-test-b sequins-test-c)

      expected_subscriptions = [
        {"sequins-test-a", "sequins-test-c", %{}},
        {"sequins-test-b", "sequins-test-c", %{}},
        {"sequins-test-a", "sequins-test-b", %{"status" => ["ok"]}}
      ]

      with actual_queues <- Sequins.Queues.list_queue_names(Sequins.prefix()) |> Enum.sort() do
        assert(actual_queues == expected_queues)
      end

      with actual_topics <- Sequins.Topics.list_topic_names(Sequins.prefix()) |> Enum.sort() do
        assert(actual_topics == expected_topics)
      end

      with actual_subscriptions <- Sequins.Subscriptions.list_subscriptions(Sequins.prefix()) do
        assert(
          expected_subscriptions
          |> Enum.all?(fn sub -> sub in actual_subscriptions end)
        )

        assert(actual_subscriptions -- expected_subscriptions == [])
      end
    end
  end
end
