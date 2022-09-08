defmodule TelemetryUI.Pruner do
  @moduledoc false

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:backend], name: __MODULE__)
  end

  @impl true
  def init(backend) do
    Process.send_after(self(), :tick, backend.pruner_interval)

    {:ok, backend}
  end

  @impl true
  def handle_info(:tick, backend) do
    date_limit = Timex.shift(DateTime.utc_now(), backend.pruner_threshold)
    TelemetryUI.Backend.prune_events!(backend, date_limit)

    Process.send_after(self(), :tick, backend.pruner_interval)

    {:noreply, backend}
  end
end
