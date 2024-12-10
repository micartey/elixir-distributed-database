defmodule EddbTest do
  use ExUnit.Case
  doctest Eddb

  test "store and retrive data" do
    pid = Database.Database.get_worker("test")
    GenServer.call(pid, {:put, "topic", "key", "value1"})
    GenServer.call(pid, {:put, "topic", "key", "value2"})
    GenServer.call(pid, {:put, "topic", "key2", "value3"})

    GenServer.call(pid, {:get, "topic", "key"})
    GenServer.call(pid, {:get, "topic", "key2"})
  end
end
