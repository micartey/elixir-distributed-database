defmodule Database.Topic do
  alias Database.Entry
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

  def replace_entry(%Topic{entries: entries} = topic, %Entry{key: key} = entry) do
    filtered_entries =
      entries
      |> Enum.filter(&(!String.equivalent?(&1.key, key)))
      |> Enum.to_list()

    %Topic{topic | entries: [entry | filtered_entries]}
  end

  def get_entry(%Topic{entries: entries}, key) do
    entries
    |> Enum.find(&String.equivalent?(&1.key, key))
  end

  def get_entry(nil, key) do
    nil
  end
end
