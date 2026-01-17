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
    store_object("topic_" <> topic_name <> ".json", new_topic)

    {:reply, entry, [new_topic | new_state]}
  end

  def handle_call({:put, topic_name, key, old_data, data}, _caller_pid, state) do
    {_, result, _} = handle_call({:get, topic_name, key}, nil, state)

    cond do
      List.first(result.history).data == old_data ->
        handle_call({:put, topic_name, key, data}, nil, state)
        {:reply, :ok, state}

      true ->
        # The data has changed
        {:reply, :fail, state}
    end
  end

  def handle_call({:delete, topic_name, key}, _caller_pid, state) do
    case get_topic_local(state, topic_name) do
      # We don't know the topic
      nil ->
        {:reply, nil, state}

      # We know the topic
      topic ->
        modified_topic = Topic.delete_entry_by_key(topic, key)

        # Store data on disc
        store_object("topic_" <> topic_name <> ".json", modified_topic)

        # State withouth the topic that has been modified
        new_state =
          state
          |> Enum.filter(&(!String.equivalent?(&1.topic, topic_name)))

        {:reply, modified_topic, [modified_topic | new_state]}
    end
  end

  def handle_call({:delete_topic, topic_name}, _caller_pid, state) do
    # Remove from state
    new_state = Enum.filter(state, &(&1.topic != topic_name))

    # Remove from disc
    if File.exists?("topic_" <> topic_name <> ".json") do
      File.rm("topic_" <> topic_name <> ".json")
    end

    {:reply, :ok, new_state}
  end

  def handle_call({:sync, topic_name}, _caller_pid, state) do
    topics = get_topics(state, topic_name)

    entries =
      topics
      |> Enum.map(fn topic -> topic.entries end)
      |> List.flatten()
      # At this point we have a list of entries which might contain duplicated keys
      |> Entry.combine()

    # entries is an array with an array of all entries of a node (|node| amount of entries)
    # We need a strategy to fold them while matching their key

    merged_topic = %Topic{
      topic: topic_name,
      entries: entries
    }

    # State withouth the topic that has been modified
    new_state =
      state
      |> Enum.filter(&(!String.equivalent?(&1.topic, topic_name)))

    # Store data on disc
    store_object("topic_" <> topic_name <> ".json", merged_topic)

    {:reply, merged_topic, [merged_topic | new_state]}
  end

  @doc """
  Find a topic not just locally, but on all nodes.
  This works as follows:

    1. Get all connected nodes
    2. Get the pid of the equivalent workers on the other nodes
    3. Call the get_topic_local method on the distante nodes
    4. Aggregate the data to a list
    5. Merge the list with local data and drop all *nil* values
  """
  def get_topics(state, topic) do
    db_worker_index = Database.Database.get_worker_index(self()) || 1

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

  @doc """
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
      File.exists?("topic_" <> topic <> ".json") ->
        retrieve_object("topic_" <> topic <> ".json")

      # We did not find a topic in the state - No data on disc
      true ->
        nil
    end
  end
end
