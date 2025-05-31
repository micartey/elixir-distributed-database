defmodule Database.Entry do
  alias Database.Entry

  defstruct key: nil,
            history: [
              %{
                timestamp: nil,
                data: nil
              }
            ]

  def new(key, data) when is_bitstring(key) do
    %Entry{
      key: key,
      history: [
        %{
          timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond),
          data: data
        }
      ]
    }
  end

  def get_keys(entries) do
    entries
    |> Stream.map(& &1.key)
    |> Enum.uniq()
  end

  @doc """
  Combine a list of Databse.Entry's for a specific key.
  This does also sort by timestamp
  """
  def combine(entries, key) do
    # TODO: This works to some degree... There is currently an "issue" where history entries
    #   with the same entries will be filtered out
    history =
      entries
      |> Stream.filter(&(&1.key == key))
      |> Enum.map(& &1.history)
      |> Stream.flat_map(& &1)
      |> Stream.uniq_by(fn %{timestamp: timestamp, data: _data} -> timestamp end)
      |> Enum.sort_by(fn %{timestamp: timestamp, data: _data} -> timestamp end, :desc)
      |> Enum.to_list()

    %Entry{
      key: key,
      history: history
    }
  end

  @doc """
  Combine a list of Databse.Entry's by key.

  The parameter is usually obtained by getting them from multiple topics, map to the entries and flatten the result:

  entries =
    topics # <-- A list of topics usually with the same topic name
    |> Enum.map(fn topic -> topic.entries end)
    |> List.flatten()
    |> Entry.combine()
  """
  def combine(entries) do
    keys = get_keys(entries)
      |> Enum.uniq()

    combine_helper([], entries, keys)
  end

  defp combine_helper(result, entries, []), do: result

  defp combine_helper(result, entries, keys) do
    key = List.first(keys)
    keys = List.delete(keys, key)

    combine_helper([combine(entries, key) | result], entries, keys)
  end

  def update(%Entry{} = entry, data) do
    %Entry{
      entry
      | history:
          List.insert_at(
            entry.history,
            0,
            %{
              timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond),
              data: data
            }
          )
    }
  end
end
