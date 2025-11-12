defmodule TelemetryUI.WriteBuffer do
  @moduledoc false

  use GenServer

  alias TelemetryUI.Backend.Entry

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
  def terminate(_reason, %State{} = state) do
    info_log(state.backend, "Flushing event buffer before shutdown…")
    do_flush(state.buffer, state.backend)
  end

  def insert(pid, event) do
    GenServer.cast(pid, {:insert, event})
    {:ok, event}
  end

  @impl GenServer
  def handle_cast({:insert, event}, %State{} = state) do
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
  def handle_info(:tick, %State{} = state) do
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
        |> to_entries(backend)
        |> Enum.each(&TelemetryUI.Backend.insert_event(backend, &1))
    end
  rescue
    error ->
      Logger.error("TelemetryUI - #{inspect(error)} Could not insert #{length(buffer)} events")
      nil
  end

  def truncate_to_bin(%DateTime{} = datetime, %{insert_date_bin: %Duration{} = date_bin}) do
    total_minutes_in_hour = datetime.minute + datetime.second / 60
    bin_time = date_bin.hour * 60 + date_bin.minute + date_bin.second / 60
    bin_minute = floor(total_minutes_in_hour / bin_time) * bin_time
    %{datetime | minute: round(bin_minute), second: 0, microsecond: {0, 0}}
  end

  def truncate_to_bin(datetime, _) do
    datetime
  end

  defp to_entries(events, backend) do
    events
    |> Enum.group_by(fn event ->
      {event.event_name, event.tags, truncate_to_bin(event.time, backend)}
    end)
    |> Enum.flat_map(fn {{name, tags, date}, events} ->
      min_value = Enum.min_by(events, & &1.value).value
      max_value = Enum.max_by(events, & &1.value).value

      case Enum.reduce(events, {0, 0}, &cast_value/2) do
        {_, 0} ->
          []

        {total_value, count} ->
          value = Float.round(Float.round(total_value / count, 3), 4)

          [
            %Entry{
              value: value,
              min_value: min_value,
              max_value: max_value,
              date: date,
              name: name,
              tags: tags,
              count: count
            }
          ]
      end
    end)
  end

  defp cast_value(event, {total_value, total_count}) do
    value =
      if is_function(event.cast_value, 1),
        do: event.cast_value.(event.value),
        else: event.value

    {value + total_value, total_count + 1}
  rescue
    error ->
      Logger.error("TelemetryUI - #{inspect(error)} Could not process event: #{inspect(event)}")
      {total_value, total_count}
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
