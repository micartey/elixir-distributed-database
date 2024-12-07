defmodule EddbTest do
  use ExUnit.Case
  doctest Eddb

  test "greets the world" do
    assert Eddb.hello() == :world
  end
end
