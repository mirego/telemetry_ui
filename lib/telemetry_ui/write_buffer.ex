defmodule TelemetryUI.WriteBuffer do
  @moduledoc false

  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    Process.flag(:trap_exit, true)
    timer = Process.send_after(self(), :tick, opts[:backend].flush_interval_ms)
    {:ok, Map.merge(Enum.into(opts, %{}), %{buffer: [], timer: timer})}
  end

  def insert(event) do
    GenServer.cast(__MODULE__, {:insert, event})
    {:ok, event}
  end

  def flush do
    GenServer.call(__MODULE__, :flush, :infinity)
    :ok
  end

  def handle_cast({:insert, event}, state = %{buffer: buffer, backend: backend}) do
    new_buffer = [event | buffer]

    if length(new_buffer) >= state[:max_buffer_size] do
      info_log(backend, "Buffer full, flushing to disk")
      Process.cancel_timer(state[:timer])
      do_flush(new_buffer, backend)
      new_timer = Process.send_after(self(), :tick, backend.flush_interval_ms)
      {:noreply, %{state | buffer: [], timer: new_timer}}
    else
      {:noreply, %{state | buffer: new_buffer}}
    end
  end

  def handle_info(:tick, state = %{buffer: buffer, backend: backend}) do
    do_flush(buffer, backend)
    timer = Process.send_after(self(), :tick, backend.flush_interval_ms)
    {:noreply, %{state | buffer: [], timer: timer}}
  end

  def handle_call(:flush, _from, state = %{buffer: buffer, backend: backend}) do
    Process.cancel_timer(state[:timer])
    do_flush(buffer, backend)
    new_timer = Process.send_after(self(), :tick, backend.flush_interval_ms)
    {:reply, nil, %{state | buffer: [], timer: new_timer}}
  end

  def terminate(_reason, %{buffer: buffer, backend: backend}) do
    info_log(backend, "Flushing event buffer before shutdown…")
    do_flush(buffer, backend)
  end

  defp do_flush(buffer, backend) do
    case buffer do
      [] ->
        nil

      events ->
        info_log(backend, "Flushing #{length(events)} events")

        events
        |> group_events()
        |> Enum.each(fn {event, {value, count}} ->
          TelemetryUI.Backend.insert_event(backend, value, event.time, event.event_name, event.tags, count, event.report_as)
        end)
    end
  end

  defp group_events(events) do
    events
    |> Enum.group_by(fn event -> %{event | value: 0} end)
    |> Enum.reduce(%{}, fn {event, values}, acc ->
      count = length(values)
      value = Float.round(Enum.reduce(values, 0, &(&1.value + &2)) / count, 3)
      Map.put(acc, event, {value, count})
    end)
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
