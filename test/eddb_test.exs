defmodule EddbTest do
  use ExUnit.Case
  doctest Eddb

  test "store and retrive data" do
    pid = Database.Database.get_worker("test")
    GenServer.call(pid, {:get, "topic", "key"})

    GenServer.call(pid, {:put, "topic", "key", "value1"})
    GenServer.call(pid, {:put, "topic", "key", "value2"})
    GenServer.call(pid, {:put, "toapic", "key2", "value3"})

    GenServer.call(pid, {:get, "topic", "key"})
    GenServer.call(pid, {:get, "topic", "key2"})
  end

  test "store and retrive data locally" do
    pid = Database.Database.get_worker("test")
    GenServer.call(pid, {:put, "topic", "key", "value1"})

    entry = GenServer.call(pid, {:get_local, "topic", "key"})

    # Could use List.first or hd/1 as well
    entry_data =
      case entry.history do
        [] -> nil
        [head | tail] -> head.data
      end

    assert entry_data == "value1"
  end

  test "fail lock" do
    pid = Database.Database.get_worker("test")
    GenServer.call(pid, {:put, "topic", "key", "value3"})
    assert GenServer.call(pid, {:put, "topic", "key", "value2", "value3"}) == :fail
  end

  test "success lock" do
    pid = Database.Database.get_worker("test")
    GenServer.call(pid, {:put, "topic", "key", "value2"})
    assert GenServer.call(pid, {:put, "topic", "key", "value2", "value2"}) == :ok
  end
end
