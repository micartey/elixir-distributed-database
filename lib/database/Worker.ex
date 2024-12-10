defmodule Database.Worker do
  alias Database.Topic
  alias Database.Entry
  require Logger
  use GenServer, restart: :permanent

  def init(init_arg) do
    {:ok, init_arg}
  end

  def start_link({index}) do
    GenServer.start_link(__MODULE__, [], name: :"db_worker_#{index}")
  end

  # TESTING:
  # pid = Database.Database.get_worker("test")
  # GenServer.call(pid, {:put, "topic", "key", "value"})
  # GenServer.call(pid, {:get, "topic", "key"})

  # TODO: Does not work for entries with changes (history > 1)
  def handle_call({:get, topic, key}, _caller_pid, state) do
    aggregated_topics = get_topic(state, topic)

    sorted_topics =
      aggregated_topics
      # Pre-Select only topics that contain the key
      |> Stream.filter(fn topic ->
        topic.entries
        |> Enum.any?(fn entry -> String.equivalent?(entry.key, key) end)
      end)
      # Get the topic that contains the entry with the highest timestamp
      |> Enum.sort_by(
        fn topic ->
          history =
            topic.entries
            |> Stream.filter(fn entry -> String.equivalent?(entry.key, key) end)
            |> Enum.map(& &1.history)
            # Get the first matching history array
            |> List.first()
            # Get the first element from history array
            |> List.first()

          history.timestamp
        end,
        :desc
      )

    IO.inspect(sorted_topics)

    entry =
      sorted_topics
      |> List.first()
      |> Topic.get_entry(key)

    {:reply, entry, state}
  end

  def handle_call({:put, topic_name, key, data}, _caller_pid, state) do
    topic =
      case get_topic_local(state, topic_name) do
        nil ->
          Topic.new(topic_name)

        topic ->
          topic
      end

    entry =
      cond do
        # Entry is present in topic, we need to append our data there
        Topic.contains_entry_with_key?(topic, key) ->
          topic.entries
          |> Enum.find(&String.equivalent?(key, &1.key))
          |> Entry.update(data)

        # Default: Topic does not yet contain the entry
        true ->
          Entry.new(key, data)
      end

    new_topic = Topic.replace_entry(topic, entry)

    new_state =
      state
      |> Enum.filter(&(!String.equivalent?(&1.topic, topic_name)))

    {:reply, entry, [new_topic | new_state]}
  end

  def get_topic(state, topic) do
    topics =
      Node.list()
      |> Enum.map(fn node ->
        :rpc.call(node, Database.Worker, :get_topic_local, [state, topic])
      end)
      |> Enum.to_list()

    # Remove nil values from list
    [get_topic_local(state, topic) | topics]
    |> Enum.filter(& &1)
    |> Enum.to_list()
  end

  defp get_topic_local(state, topic) do
    state
    |> Enum.find(&String.equivalent?(topic, &1.topic))
  end
end
