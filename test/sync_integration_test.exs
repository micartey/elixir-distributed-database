defmodule Eddb.SyncIntegrationTest do
  use ExUnit.Case
  alias Database.Topic
  alias Database.Entry
  alias Database.Database
  alias Eddb.Facade
  alias Utilities.Serialize

  setup do
    # Cleanup before and after tests
    on_exit(fn ->
      File.rm_rf!("sync_test_topic.json")
      # Delete from all workers
      Facade.delete_topic("sync_test_topic")
    end)

    :ok
  end

  test "sync_topic uses the (n+1)th worker when topic is not loaded" do
    topic_name = "sync_test_topic"
    temp_worker_index = Database.pool_size() + 1
    temp_worker_name = :"db_worker_#{temp_worker_index}"

    # 1. Ensure the topic is NOT loaded in any worker (1..10)
    # We'll just check their state
    workers_with_topic = Database.get_workers_with_topic(node(), topic_name)
    assert workers_with_topic == []

    # 2. Create a "ghost" topic on disk to simulate it existing elsewhere or being old
    # Actually, sync_topic calls get_topics which tries to aggregate from all nodes.
    # We can just put a file on disk.
    topic =
      struct(Topic,
        topic: topic_name,
        entries: [
          struct(Entry, key: "sync_key", history: [%{data: "synced_value", timestamp: 1}])
        ]
      )

    Serialize.store_object("topic_#{topic_name}.json", topic)

    # 3. Trigger sync_topic
    # Since no worker (1..10) has it, it should hit the 11th worker.
    Facade.sync_topic(topic_name)

    # 4. Verify the 11th worker now has the topic in its state
    temp_worker_pid = Process.whereis(temp_worker_name)
    assert temp_worker_pid != nil

    state = GenServer.call(temp_worker_pid, {:get_state})
    assert Enum.any?(state, fn t -> t.topic == topic_name end)

    # 5. Verify the first 10 workers STILL do not have it (no pollution)
    workers_with_topic_after = Database.get_workers_with_topic(node(), topic_name)
    assert Enum.reject(workers_with_topic_after, &(&1 == temp_worker_pid)) == []
  end
end
