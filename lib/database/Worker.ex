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
    case get_topic(state, topic) do
      # Search on other nodes if topic is unknown locally
      nil ->
        result =
          Node.list()
          |> Enum.find(fn node ->
            pid = :rpc.call(node, Database.Database, :get_worker, [topic])
            :rpc.call(node, GenServer, :call, [pid, {:get, topic, key}])
          end)
          |> Enum.map(& &1.entries)
          |> Enum.find(&(&1.key == key))

        {:reply, result, state}

      topic ->
        topic
        |> Enum.map(& &1.entries)
        |> Enum.find(&(&1.key == key))
    end
  end

  # def handle_call({:put, topic_name, %Entry{} = entry}, _caller_pid, state) do
  #   topic =
  #     case get_topic(state, topic_name) do
  #       nil ->
  #         Topic.new(topic_name)

  #       topic ->
  #         topic
  #     end
  # end

  def get_topic(state, topic) do
    state
    |> Enum.find(&String.equivalent?(topic, &1.topic))
  end
end
