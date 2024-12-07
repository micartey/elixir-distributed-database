defmodule Utilities.Serialize do

  def store_object(file_path, object) do
    binary = :erlang.term_to_binary(object)
    File.write!(file_path, binary)
  end

  def retrieve_object(file_path) do
    binary = File.read!(file_path)
    :erlang.binary_to_term(binary)
  end


end
