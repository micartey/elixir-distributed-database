defmodule Database.Topic do
  alias Database.Topic
  defstruct topic: nil, entries: []

  def new(topic) when is_bitstring(topic) do
    %Topic{
      topic: topic
    }
  end
end
