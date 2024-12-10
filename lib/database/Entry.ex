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
