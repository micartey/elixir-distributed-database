defmodule EddbTest do
  use ExUnit.Case
  doctest Eddb

  @topic "test_topic"

  setup do
    on_exit(fn ->
      Path.wildcard("topic_#{@topic}*.json") |> Enum.each(&File.rm/1)
    end)

    :ok
  end

  test "store and retrive data" do
    pid = Database.Database.get_worker("test")
    GenServer.call(pid, {:get, @topic, "key"})

    GenServer.call(pid, {:put, @topic, "key", "value1"})
    GenServer.call(pid, {:put, @topic, "key", "value2"})
    GenServer.call(pid, {:put, @topic, "key2", "value3"})

    GenServer.call(pid, {:get, @topic, "key"})
    GenServer.call(pid, {:get, @topic, "key2"})
  end

  test "store and retrive data locally" do
    pid = Database.Database.get_worker("test")
    GenServer.call(pid, {:put, @topic, "key", "value1"})

    entry = GenServer.call(pid, {:get_local, @topic, "key"})

    # Could use List.first or hd/1 as well
    entry_data =
      case entry.history do
        [] -> nil
        [head | _tail] -> head.data
      end

    assert entry_data == "value1"
  end

  test "fail lock" do
    pid = Database.Database.get_worker("test")
    GenServer.call(pid, {:put, @topic, "key", "value3"})
    assert GenServer.call(pid, {:put, @topic, "key", "value2", "value3"}) == :fail
  end

  test "success lock" do
    pid = Database.Database.get_worker("test")
    GenServer.call(pid, {:put, @topic, "key", "value2"})
    assert GenServer.call(pid, {:put, @topic, "key", "value2", "value2"}) == :ok
  end

  test "delete data" do
    pid = Database.Database.get_worker("test")
    GenServer.call(pid, {:put, @topic, "key", "test"})
    GenServer.call(pid, {:put, @topic, "key", "123123"})
    GenServer.call(pid, {:put, @topic, "key", "asdasd"})
    data = GenServer.call(pid, {:get, @topic, "key"})
    assert data != nil

    GenServer.call(pid, {:delete, @topic, "key"})
    entry = GenServer.call(pid, {:get_local, @topic, "key"})

    assert entry == nil
  end
end
