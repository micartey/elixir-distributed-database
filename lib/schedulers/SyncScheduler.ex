defmodule Schedulers.SyncScheduler do
  use GenServer
  require Logger
  alias Eddb.Facade

  # 1 hour
  @interval 60 * 60 * 1000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    schedule_sync()
    {:ok, state}
  end

  @impl true
  def handle_info(:sync, state) do
    Logger.info("Starting periodic sync...")
    Facade.sync()
    Logger.info("Periodic sync completed.")
    schedule_sync()
    {:noreply, state}
  end

  defp schedule_sync do
    Process.send_after(self(), :sync, @interval)
  end
end
