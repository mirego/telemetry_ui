defmodule TelemetryUI.WriteBuffer do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    Process.flag(:trap_exit, true)
    timer = Process.send_after(self(), :tick, opts[:flush_interval_ms])
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

  def handle_cast({:insert, event}, state = %{buffer: buffer, adapter: adapter}) do
    new_buffer = [event | buffer]

    if length(new_buffer) >= state[:max_buffer_size] do
      Logger.info("Buffer full, flushing to disk")
      Process.cancel_timer(state[:timer])
      do_flush(new_buffer, adapter)
      new_timer = Process.send_after(self(), :tick, state[:flush_interval_ms])
      {:noreply, %{state | buffer: [], timer: new_timer}}
    else
      {:noreply, %{state | buffer: new_buffer}}
    end
  end

  def handle_info(:tick, state = %{buffer: buffer, adapter: adapter}) do
    do_flush(buffer, adapter)
    timer = Process.send_after(self(), :tick, state[:flush_interval_ms])
    {:noreply, %{state | buffer: [], timer: timer}}
  end

  def handle_call(:flush, _from, state = %{buffer: buffer, adapter: adapter}) do
    Process.cancel_timer(state[:timer])
    do_flush(buffer, adapter)
    new_timer = Process.send_after(self(), :tick, state[:flush_interval_ms])
    {:reply, nil, %{state | buffer: [], timer: new_timer}}
  end

  def terminate(_reason, %{buffer: buffer, adapter: adapter}) do
    Logger.info("Flushing event buffer before shutdown…")
    do_flush(buffer, adapter)
  end

  defp do_flush(buffer, adapter) do
    case buffer do
      [] ->
        nil

      events ->
        Logger.info("Flushing #{length(events)} events")

        events
        |> group_events()
        |> Enum.each(fn {event, {value, count}} ->
          adapter.insert_event(value, event.time, event.event_name, event.tags, event.bucket, count)
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
end
