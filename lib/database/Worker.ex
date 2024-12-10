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
        # Get topics sorted by timestamp
        # 1. Filter only entries that have the searched key
        # 2. Get history
        # 3. Sort timestamps in descending order
        # 4. Get first element (Element with highest timestamp)
        fn topic ->
          topic.entries
          |> Stream.filter(fn entry -> String.equivalent?(entry.key, key) end)
          |> Stream.map(& &1.history)
          |> Enum.sort_by(& &1.timestamp, :desc)
          |> List.first()
        end,
        :desc
      )

    IO.inspect(sorted_topics)

    {:reply, nil, state}
  end

  def handle_call({:put, topic_name, %Entry{} = entry}, _caller_pid, state) do
    topic =
      case get_topic_local(state, topic_name) do
        nil ->
          Topic.new(topic_name)

        topic ->
          topic
      end

    # TODO: Implement
    cond do
      Topic.contains_entry_with_key?(topic, entry.key) ->
        nil

      true ->
        nil
    end
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
