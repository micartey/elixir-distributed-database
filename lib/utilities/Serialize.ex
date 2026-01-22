defmodule Utilities.Serialize do
  def store_object(file_path, object) do
    json_string = Poison.encode!(object)

    case System.get_env("EDDB_IN_MEMORY") do
      nil ->
        File.write!(file_path, json_string)

      _ ->
        nil
    end
  end

  def retrieve_object(file_path) do
    case File.read(file_path) do
      {:ok, json_string} ->
        Poison.DecodeWithStruct.decode!(json_string)

      {:error, reason} ->
        IO.inspect("Error reading file #{file_path}: #{reason}")
        nil
    end
  end
end

defmodule Poison.DecodeWithStruct do
  def decode!(json_string) do
    data_map = Poison.decode!(json_string, keys: :atoms)
    to_struct(data_map)
  end

  def to_struct(%{:__struct__ => module_name_str} = map_with_string_keys) do
    module = String.to_atom("Elixir." <> module_name_str)

    map_with_atom_keys_and_processed_values =
      map_with_string_keys
      |> Enum.map(fn {key, value} ->
        processed_value =
          cond do
            # Check if 'value' is a map AND it contains the "__struct__" string key
            is_map(value) and Map.has_key?(value, :__struct__) ->
              to_struct(value)

            is_list(value) ->
              Enum.map(value, &maybe_to_struct/1)

            true ->
              value
          end

        {key, processed_value}
      end)
      |> Enum.into(%{})

    struct_fields = Map.delete(map_with_atom_keys_and_processed_values, :__struct__)
    struct(module, struct_fields)
  end

  # Handles items that are not maps or don't have "__struct__"
  def to_struct(other), do: other

  # Helper for list processing
  defp maybe_to_struct(%{:__struct__ => _} = item_map), do: to_struct(item_map)
  defp maybe_to_struct(item), do: item
end

defimpl Poison.Encoder, for: Database.Entry do
  def encode(%Database.Entry{} = doc, opts) do
    doc
    |> Map.from_struct()
    |> Map.put("__struct__", inspect(doc.__struct__))
    |> Poison.Encoder.Map.encode(opts)
  end
end

defimpl Poison.Encoder, for: Database.Topic do
  def encode(%Database.Topic{} = doc, opts) do
    doc
    |> Map.from_struct()
    |> Map.put("__struct__", inspect(doc.__struct__))
    |> Poison.Encoder.Map.encode(opts)
  end
end

defimpl Poison.Encoder, for: User.User do
  def encode(%User.User{} = doc, opts) do
    doc
    |> Map.from_struct()
    |> Map.put("__struct__", inspect(doc.__struct__))
    |> Poison.Encoder.Map.encode(opts)
  end
end
