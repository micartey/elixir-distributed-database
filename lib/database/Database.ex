defmodule Database.Database do
  alias Database.Worker

  @pool_size 10

  def init(state) do
    {:ok, state}
  end

  def start_link() do
    IO.puts("Starting Database Supervisor")

    children =
      1..(@pool_size + 1)
      |> Enum.map(fn index -> Supervisor.child_spec({Worker, {index}}, id: index) end)

    IO.puts("Started #{length(children)} workers")

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker
    }
  end

  def get_worker(key) when is_bitstring(key) do
    index = :erlang.phash2(key, @pool_size) + 1
    Process.whereis(:"db_worker_#{index}")
  end

  def get_remote_worker(node, key) when is_bitstring(key) do
    :rpc.call(node, Database.Database, :get_worker, [key])
  end

  def list_topics() do
    nodes = [node() | Node.list()]

    nodes
    |> Enum.flat_map(fn node ->
      1..@pool_size
      |> Enum.flat_map(fn index ->
        case get_worker_state(node, index) do
          topics when is_list(topics) -> Enum.map(topics, & &1.topic)
          _ -> []
        end
      end)
    end)
    |> Enum.uniq()
  end

  def get_workers_with_topic(node, topic_name) do
    1..@pool_size
    |> Enum.map(fn index ->
      :rpc.call(node, Process, :whereis, [:"db_worker_#{index}"])
    end)
    |> Enum.filter(fn
      pid when is_pid(pid) ->
        case :rpc.call(node, GenServer, :call, [pid, {:get_state}]) do
          state when is_list(state) ->
            Enum.any?(state, fn t -> t.topic == topic_name end)

          _ ->
            false
        end

      _ ->
        false
    end)
  end

  def delete_topic(topic_name) do
    nodes = [node() | Node.list()]

    nodes
    |> Enum.each(fn node ->
      1..@pool_size
      |> Enum.each(fn index ->
        worker = :rpc.call(node, Process, :whereis, [:"db_worker_#{index}"])
        if worker, do: :rpc.call(node, GenServer, :call, [worker, {:delete_topic, topic_name}])
      end)
    end)

    :ok
  end

  defp get_worker_state(node, index) do
    worker = :rpc.call(node, Process, :whereis, [:"db_worker_#{index}"])
    if worker, do: :rpc.call(node, GenServer, :call, [worker, {:get_state}]), else: nil
  end

  def pool_size, do: @pool_size
end
