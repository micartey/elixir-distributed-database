defmodule Eddb.Facade do
  @moduledoc """
  A facade providing easy-to-use commands for managing users, topics, and entries.
  """

  alias User.User
  alias Database.Worker
  alias Database.Database

  # User Management

  def create_user(username, password, permissions \\ []) do
    User.create_user(username, password, permissions)
  end

  def delete_user(username) do
    User.delete_user(username)
  end

  def add_topic_to_user(username, topic) do
    User.add_topic(username, topic)
  end

  def remove_topic_from_user(username, topic) do
    User.remove_topic(username, topic)
  end

  def list_users do
    User.sync()
    Process.whereis(:user_server) |> GenServer.call({:get_state})
  end

  # Database/Topic Management

  def list_topics do
    loaded_topics = Database.list_topics()

    disk_topics =
      Path.wildcard("topic_*.json")
      |> Enum.map(fn path ->
        path
        |> String.replace("topic_", "")
        |> String.replace(".json", "")
      end)

    (loaded_topics ++ disk_topics)
    |> Enum.uniq()
  end

  def create_topic(topic_name) do
    # In this system, topics are created on first put.
    # We can "create" one by putting a dummy key or just acknowledging it's dynamic.
    # But for the facade, we'll just say it's ready.
    IO.puts("Topic #{topic_name} will be created upon first entry.")
    :ok
  end

  def delete_topic(topic_name) do
    Database.delete_topic(topic_name)
  end

  # Entry Management

  def put(topic, key, value) do
    worker = Database.get_worker(key)
    GenServer.call(worker, {:put, topic, key, value})
  end

  def get(topic, key) do
    worker = Database.get_worker(key)
    GenServer.call(worker, {:get, topic, key})
  end

  def delete(topic, key) do
    worker = Database.get_worker(key)
    GenServer.call(worker, {:delete, topic, key})
  end

  # Sync Management

  def sync_topic(topic_name) do
    nodes = [node() | Node.list()]

    nodes
    |> Enum.each(fn node ->
      # We need to find which workers might have this topic.
      # Since we don't know the keys, we ask all workers to sync this topic name.
      # This will - however - polute all workers with the topic even if they don't handle it
      1..Database.pool_size()
      |> Enum.each(fn index ->
        worker = :rpc.call(node, Process, :whereis, [:"db_worker_#{index}"])
        :rpc.call(node, GenServer, :call, [worker, {:sync, topic_name}])
      end)
    end)

    :ok
  end

  def sync_all do
    list_topics()
    |> Enum.each(&sync_topic/1)

    :ok
  end

  # Helpers

  def query_topic(topic_name) do
    nodes = [node() | Node.list()]

    # 1. Scan state of all workers
    found_topic =
      Enum.find_value(nodes, fn node ->
        1..Database.pool_size()
        |> Enum.find_value(fn index ->
          worker = :rpc.call(node, Process, :whereis, [:"db_worker_#{index}"])

          if worker do
            case :rpc.call(node, GenServer, :call, [worker, {:get_state}]) do
              topics when is_list(topics) ->
                Enum.find(topics, fn t -> t.topic == topic_name end)

              _ ->
                nil
            end
          end
        end)
      end)

    if found_topic do
      found_topic
    else
      # 2. Temporary worker logic
      topic_from_disk = Worker.get_topic_local([], topic_name)
      initial_state = if topic_from_disk, do: [topic_from_disk], else: []

      {:ok, pid} = GenServer.start_link(Worker, initial_state)
      synced_topic = GenServer.call(pid, {:sync, topic_name})
      GenServer.stop(pid)

      synced_topic
    end
  end
end
