defmodule Database.Worker do
  alias Utilities.Serialize
  alias Database.Topic
  alias Database.Entry
  alias Utilities.Serialize
  import Serialize
  require Logger
  use GenServer, restart: :permanent

  def init(init_arg) do
    {:ok, init_arg}
  end

  def start_link({index}) do
    GenServer.start_link(__MODULE__, [], name: :"db_worker_#{index}")
  end

  def handle_call({:get_state}, _caller_pid, state) do
    {:reply, state, state}
  end

  def handle_call({:get, topic, key}, _caller_pid, state) do
    aggregated_topics = get_topics(state, topic)

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

    entry =
      sorted_topics
      |> List.first()
      |> Topic.get_entry(key)

    {:reply, entry, state}
  end

  def handle_call({:get_local, topic, key}, _caller_pid, state) do
    entry =
      get_topic_local(state, topic)
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

    # Store data on disc
    store_object("topic_" <> topic_name <> ".bin", new_topic)

    {:reply, entry, [new_topic | new_state]}
  end

  def handle_call({:put, topic_name, key, old_data, data}, caller_pid, state) do
    {_, result, _} = handle_call({:get, topic_name, key}, caller_pid, state)

    cond do
      List.first(result.history).data == old_data ->
        handle_call({:put, topic_name, key, data}, caller_pid, state)
        {:reply, :ok, state}

      true ->
        # The data has changed
        {:reply, :fail, state}
    end
  end

  def handle_call({:sync, topic_name}, _caller_pid, state) do
    topics = get_topics(state, topic_name)

    entries =
      topics
      |> Enum.map(fn topic ->
        Entry.get_keys(topic.entries)
        |> Enum.map(fn key ->
          Entry.combine(topic.entries, key)
        end)
      end)
      |> List.flatten()

    merged_topic = %Topic{
      topic: topic_name,
      entries: entries
    };

    # Store data on disc
    store_object("topic_" <> topic_name <> ".bin", merged_topic)

    {:reply, merged_topic, [merged_topic | state]}
  end

  @moduledoc """
  Find a topic not just locally, but on all nodes.
  This works as follows:

    1. Get all connected nodes
    2. Get the pid of the equivalent workers on the other nodes
    3. Call the get_topic_local method on the distante nodes
    4. Aggregate the data to a list
    5. Merge the list with local data and drop all *nil* values
  """
  def get_topics(state, topic) do
    db_worker_index = Database.Database.get_worker_index(self())

    topics =
      Node.list()
      |> Enum.map(fn node ->
        remote_worker_pid = :rpc.call(node, Process, :whereis, [:"db_worker_#{db_worker_index}"])
        remote_state = :rpc.call(node, GenServer, :call, [remote_worker_pid, {:get_state}])
        :rpc.call(node, Database.Worker, :get_topic_local, [remote_state, topic])
      end)
      |> Enum.to_list()

    [get_topic_local(state, topic) | topics]
    |> Enum.filter(& &1)
    |> Enum.to_list()
  end

  @moduledoc """
  Find a topic by name in current state.
  If there is no match in state, try to retrive data from disc.
  If there is no data on disc, return *nil*
  """
  def get_topic_local(state, topic) do
    result =
      state
      |> Enum.find(&String.equivalent?(topic, &1.topic))

    cond do
      # We found a topic in the state - Data has already been loaded from disc
      result ->
        result

      # We did not find a topic in the state - Load data from disc
      File.exists?("topic_" <> topic <> ".bin") ->
        retrieve_object("topic_" <> topic <> ".bin")

      # We did not find a topic in the state - No data on disc
      true ->
        nil
    end
  end
end
