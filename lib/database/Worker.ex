defmodule Database.Worker do
  require Logger
  use GenServer, restart: :permanent

  def init(init_arg) do
    {:ok, init_arg}
  end

  def start_link({index}) do
    GenServer.start_link(__MODULE__, Map.new(), name: :"db_worker_#{index}")
  end

end
