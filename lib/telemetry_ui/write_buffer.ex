defmodule TelemetryUI.WriteBuffer do
  @moduledoc false

  use GenServer
  require Logger

  defmodule State do
    @moduledoc false

    @enforce_keys ~w(backend buffer timer)a
    defstruct backend: nil, buffer: [], timer: nil
  end

  def start_link(initial_state) do
    GenServer.start_link(__MODULE__, initial_state, name: initial_state[:name])
  end

  @impl GenServer
  def init(opts) do
    Process.flag(:trap_exit, true)
    timer = Process.send_after(self(), :tick, opts[:backend].flush_interval_ms)

    {:ok,
     %State{
       backend: opts[:backend],
       buffer: [],
       timer: timer
     }}
  end

  @impl GenServer
  def terminate(_reason, state = %State{}) do
    info_log(state.backend, "Flushing event buffer before shutdown…")
    do_flush(state.buffer, state.backend)
  end

  def insert(pid, event) do
    GenServer.cast(pid, {:insert, event})
    {:ok, event}
  end

  @impl GenServer
  def handle_cast({:insert, event}, state = %State{}) do
    new_buffer = [event | state.buffer]

    if length(new_buffer) >= state.backend.max_buffer_size do
      info_log(state.backend, "Buffer full, flushing to disk")
      state.timer && Process.cancel_timer(state.timer)
      do_flush(new_buffer, state.backend)
      new_timer = Process.send_after(self(), :tick, state.backend.flush_interval_ms)
      {:noreply, %{state | buffer: [], timer: new_timer}}
    else
      {:noreply, %{state | buffer: new_buffer}}
    end
  end

  @impl GenServer
  def handle_info(:tick, state = %State{}) do
    do_flush(state.buffer, state.backend)
    timer = Process.send_after(self(), :tick, state.backend.flush_interval_ms)
    {:noreply, %{state | buffer: [], timer: timer}}
  end

  defp do_flush(buffer, backend) do
    case buffer do
      [] ->
        nil

      events ->
        info_log(backend, "Flushing #{length(events)} events")

        events
        |> group_events(backend)
        |> Enum.each(fn {event, {value, count}} ->
          TelemetryUI.Backend.insert_event(backend, value, event.time, event.event_name, event.tags, count, event.report_as)
        end)
    end
  end

  defp group_events(events, backend) do
    events
    |> Enum.map(&%{&1 | time: truncate_time(&1.time, backend)})
    |> Enum.group_by(fn event -> %{event | value: 0} end)
    |> Enum.reduce(%{}, fn {event, values}, acc ->
      count = length(values)
      value = Float.round(Enum.reduce(values, 0, &(&1.value + &2)) / count, 3)
      Map.put(acc, event, {value, count})
    end)
  end

  defp truncate_time(time, backend) do
    time = DateTime.truncate(time, :second)

    case backend.insert_date_trunc do
      "minute" -> Timex.set(time, second: 0)
      "second" -> time
    end
  end

  defp info_log(backend, message) do
    message = "TelemetryUI - " <> message

    cond do
      is_nil(backend.verbose) -> nil
      backend.verbose === false -> nil
      backend.verbose === true -> Logger.debug(message)
      is_atom(backend.verbose) -> Logger.log(backend.verbose, message)
    end
  end
end
