defmodule Database.Database do
  alias Database.Worker

  @pool_size 10

  def init(state) do
    {:ok, state}
  end

  def start_link() do
    IO.puts("Starting Database Supervisor")

    children =
      1..@pool_size
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

  def get_worker_index(pid) do
    get_worker_index_itr(pid, 0)
  end

  defp get_worker_index_itr(pid, index) do
    cond do
      index > @pool_size ->
        nil

      Process.whereis(:"db_worker_#{index}") == pid ->
        index

      true ->
        get_worker_index_itr(pid, index + 1)
    end
  end

  def list_topics() do
    nodes = [node() | Node.list()]

    nodes
    |> Enum.flat_map(fn node ->
      1..@pool_size
      |> Enum.flat_map(fn index ->
        worker = :rpc.call(node, Process, :whereis, [:"db_worker_#{index}"])

        case :rpc.call(node, GenServer, :call, [worker, {:get_state}]) do
          topics when is_list(topics) -> Enum.map(topics, & &1.topic)
          _ -> []
        end
      end)
    end)
    |> Enum.uniq()
  end

  def delete_topic(topic_name) do
    nodes = [node() | Node.list()]

    nodes
    |> Enum.each(fn node ->
      1..@pool_size
      |> Enum.each(fn index ->
        worker = :rpc.call(node, Process, :whereis, [:"db_worker_#{index}"])
        :rpc.call(node, GenServer, :call, [worker, {:delete_topic, topic_name}])
      end)
    end)

    :ok
  end

  def pool_size, do: @pool_size
end
