defmodule EddbTest do
  use ExUnit.Case
  doctest Eddb

  test "add data to database" do
    pid = Database.Database.get_worker("test")
    GenServer.call(pid, {:put, "topic", "key", "value1"})
    GenServer.call(pid, {:put, "topic", "key", "value2"})
    GenServer.call(pid, {:put, "topic", "key2", "value3"})
  end

  test "retrive data from database" do
    pid = Database.Database.get_worker("test")
    GenServer.call(pid, {:get, "topic", "key"})
    GenServer.call(pid, {:get, "topic", "key2"})
  end
end
