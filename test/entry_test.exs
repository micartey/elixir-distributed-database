defmodule Database.EntryTest do
  use ExUnit.Case
  alias Database.Entry

  test "combine/1 merges multiple entries with the same key" do
    entry1 = %Entry{
      key: "k1",
      history: [%{timestamp: 10, data: "v1"}]
    }

    entry2 = %Entry{
      key: "k1",
      history: [%{timestamp: 20, data: "v2"}]
    }

    entry3 = %Entry{
      key: "k2",
      history: [%{timestamp: 15, data: "v3"}]
    }

    entries = [entry1, entry2, entry3]
    combined = Entry.combine(entries)

    assert length(combined) == 2

    k1_entry = Enum.find(combined, &(&1.key == "k1"))
    assert length(k1_entry.history) == 2
    # Should be sorted by timestamp desc
    assert Enum.at(k1_entry.history, 0).timestamp == 20
    assert Enum.at(k1_entry.history, 1).timestamp == 10

    k2_entry = Enum.find(combined, &(&1.key == "k2"))
    assert length(k2_entry.history) == 1
    assert Enum.at(k2_entry.history, 0).data == "v3"
  end

  test "combine/1 removes duplicate history entries by timestamp" do
    # This matches the @doc in Entry.ex about Stream.uniq_by timestamp
    entry1 = %Entry{
      key: "k1",
      history: [%{timestamp: 10, data: "v1"}]
    }

    entry2 = %Entry{
      key: "k1",
      history: [%{timestamp: 10, data: "v1_duplicate"}]
    }

    combined = Entry.combine([entry1, entry2])
    assert length(combined) == 1
    assert length(List.first(combined).history) == 1
  end
end
