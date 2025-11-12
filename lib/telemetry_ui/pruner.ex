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
    date_limit = shift_datetime(DateTime.utc_now(), backend.pruner_threshold)
    TelemetryUI.Backend.prune_events!(backend, date_limit)

    Process.send_after(self(), :tick, backend.pruner_interval_ms)

    {:noreply, backend}
  end

  defp shift_datetime(datetime, shifts) do
    Enum.reduce(shifts, datetime, fn {unit, value}, acc ->
      case unit do
        :years -> DateTime.add(acc, value * 365, :day)
        :months -> DateTime.add(acc, value * 30, :day)
        :weeks -> DateTime.add(acc, value * 7, :day)
        :days -> DateTime.add(acc, value, :day)
        :hours -> DateTime.add(acc, value, :hour)
        :minutes -> DateTime.add(acc, value, :minute)
        :seconds -> DateTime.add(acc, value, :second)
        _ -> acc
      end
    end)
  end
end
