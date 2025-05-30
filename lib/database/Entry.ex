defmodule Database.Entry do
  alias Database.Entry

  defstruct key: nil,
            history: [
              %{
                timestamp: nil,
                data: nil
              }
            ]

  def get_keys(entries) do
    entries
    |> Stream.map(& &1.key)
    |> Enum.uniq()
  end

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
