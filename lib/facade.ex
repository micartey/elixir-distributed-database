defmodule Eddb.Facade do
  @moduledoc """
  A facade providing easy-to-use commands for managing users, topics, and entries.
  """

  require Logger
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

    nodes = [node() | Node.list()]

    disk_topics =
      nodes
      |> Enum.flat_map(fn node ->
        :rpc.call(node, Path, :wildcard, ["topic_*.json"])
        |> Enum.map(fn path ->
          path
          |> String.replace("topic_", "")
          |> String.replace(".json", "")
        end)
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

  def sync do
    # 1. Sync users
    sync_users()

    # 2. Sync all topics
    sync_topics()
  end

  def sync_topic(topic_name) do
    nodes = [node() | Node.list()]

    nodes
    |> Enum.each(fn node ->
      case Database.get_workers_with_topic(node, topic_name) do
        [] ->
          # No worker has this topic loaded
          {:ok, pid} = :rpc.call(node, GenServer, :start_link, [Worker, []])
          GenServer.call(pid, {:sync, topic_name})
          GenServer.stop(pid)

        workers ->
          # One or more workers have this topic, sync all of them
          Enum.each(workers, fn pid ->
            :rpc.call(node, GenServer, :call, [pid, {:sync, topic_name}])
          end)
      end
    end)

    :ok
  end

  def sync_topics do
    list_topics()
    |> Enum.each(&sync_topic/1)

    :ok
  end

  def sync_users do
    User.sync()
  end

  # Helpers

  def query_topic(topic_name) do
    workers = Database.get_workers_with_topic(node(), topic_name)

    initial_state =
      case workers do
        [worker_pid | _] ->
          state = GenServer.call(worker_pid, {:get_state})
          topic = Enum.find(state, &(&1.topic == topic_name))
          [topic]

        [] ->
          []
      end

    {:ok, pid} = GenServer.start_link(Worker, initial_state)
    synced_topic = GenServer.call(pid, {:sync, topic_name})
    GenServer.stop(pid)

    synced_topic
  end
end
