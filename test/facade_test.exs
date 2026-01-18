defmodule Eddb.FacadeTest do
  use ExUnit.Case
  alias Eddb.Facade
  alias Database.Topic
  alias Database.Entry
  alias Utilities.Serialize

  setup do
    on_exit(fn ->
      ["facade_state_topic", "facade_disk_topic"]
      |> Enum.each(&Facade.delete_topic/1)

      Path.wildcard("topic_facade_*.json") |> Enum.each(&File.rm/1)
    end)

    :ok
  end

  test "query_topic returns topic from worker state" do
    topic_name = "facade_state_topic"
    Facade.put(topic_name, "key1", "value1")

    topic = Facade.query_topic(topic_name)

    assert topic.topic == topic_name
    assert length(topic.entries) == 1
    assert List.first(topic.entries).key == "key1"
  end

  test "query_topic returns topic from disk via temp worker if not in state" do
    topic_name = "facade_disk_topic"
    filename = "topic_#{topic_name}.json"

    topic = %Topic{
      topic: topic_name,
      entries: [
        %Entry{
          key: "k1",
          history: [%{data: "v1", timestamp: 123}]
        }
      ]
    }

    Serialize.store_object(filename, topic)

    queried_topic = Facade.query_topic(topic_name)

    assert queried_topic.topic == topic_name
    assert length(queried_topic.entries) == 1
    assert List.first(queried_topic.entries).key == "k1"
  end
end
