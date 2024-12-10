defmodule Database.Topic do
  alias Database.Topic
  defstruct topic: nil, entries: []

  def new(topic) when is_bitstring(topic) do
    %Topic{
      topic: topic
    }
  end

  def contains_entry_with_key?(%Topic{entries: entries}, key) do
    entries
    |> Enum.any?(&String.equivalent?(&1.key, key))
  end
end
