defmodule TelemetryUI.Pruner do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(state) do
    Process.send_after(self(), :tick, state[:interval])

    {:ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    date_limit = Timex.shift(DateTime.utc_now(), state[:threshold])
    state.adapter.prune_events!(date_limit)

    Process.send_after(self(), :tick, state[:interval])

    {:noreply, state}
  end
end
