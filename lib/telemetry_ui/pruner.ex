defmodule TelemetryUI.Pruner do
  @moduledoc false

  use GenServer

  def start_link(initial_state) do
    GenServer.start_link(__MODULE__, initial_state[:backend])
  end

  @impl GenServer
  def init(backend) do
    Process.send_after(self(), :tick, backend.pruner_interval_ms)

    {:ok, backend}
  end

  @impl GenServer
  def handle_info(:tick, backend) do
    date_limit = Timex.shift(DateTime.utc_now(), backend.pruner_threshold)
    TelemetryUI.Backend.prune_events!(backend, date_limit)

    Process.send_after(self(), :tick, backend.pruner_interval_ms)

    {:noreply, backend}
  end
end
