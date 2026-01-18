defmodule Database.WorkerTest do
  use ExUnit.Case
  alias Database.Worker
  alias Database.Topic
  alias Database.Entry
  alias Utilities.Serialize

  @topic "worker_test_topic"

  setup do
    on_exit(fn ->
      File.rm_rf("topic_#{@topic}.json")
    end)

    :ok
  end

  test "handle_call :sync returns merged topic and updates state" do
    # 1. Prepare an entry that will be in our "state"
    entry1 = %Entry{
      key: "key1",
      history: [%{timestamp: 200, data: "new_value"}]
    }

    initial_state = [%Topic{topic: @topic, entries: [entry1]}]

    # 2. Call :sync. 
    # On a single node with Node.list() == [], it will only use get_topic_local.
    # get_topic_local will return the topic from state.
    {:reply, merged_topic, new_state} = Worker.handle_call({:sync, @topic}, nil, initial_state)

    # 3. Assertions
    assert merged_topic.topic == @topic
    assert length(merged_topic.entries) == 1
    assert Enum.at(merged_topic.entries, 0).key == "key1"

    # Verify the state was updated (should contain the merged topic)
    assert length(new_state) == 1
    assert Enum.at(new_state, 0) == merged_topic

    # Verify it was saved to disk
    assert File.exists?("topic_#{@topic}.json")
    disk_topic = Serialize.retrieve_object("topic_#{@topic}.json")
    assert disk_topic == merged_topic
  end

  test "handle_call :sync loads from disk if not in state" do
    # 1. Prepare disk data
    entry_disk = %Entry{
      key: "key1",
      history: [%{timestamp: 100, data: "disk_value"}]
    }

    topic_disk = %Topic{topic: @topic, entries: [entry_disk]}
    Serialize.store_object("topic_#{@topic}.json", topic_disk)

    # 2. Call :sync with empty state
    {:reply, merged_topic, new_state} = Worker.handle_call({:sync, @topic}, nil, [])

    # 3. Assertions
    assert merged_topic.topic == @topic
    assert merged_topic.entries == [entry_disk]
    assert new_state == [merged_topic]
  end

  test "get_topic_local prefers state over disk" do
    # 1. Prepare disk data
    entry_disk = %Entry{key: "key1", history: [%{timestamp: 100, data: "disk"}]}
    Serialize.store_object("topic_#{@topic}.json", %Topic{topic: @topic, entries: [entry_disk]})

    # 2. Prepare state data
    entry_state = %Entry{key: "key1", history: [%{timestamp: 200, data: "state"}]}
    state = [%Topic{topic: @topic, entries: [entry_state]}]

    # 3. Check get_topic_local
    result = Worker.get_topic_local(state, @topic)
    assert List.first(result.entries).history |> List.first() |> Map.get(:data) == "state"
  end
end
