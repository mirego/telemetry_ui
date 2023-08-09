defmodule TelemetryUI.Reporter do
  @moduledoc false

  use GenServer

  import TelemetryUI.Event

  require Logger

  def start_link(initial_state) do
    GenServer.start_link(__MODULE__, {initial_state[:write_buffer], initial_state[:metrics]})
  end

  @impl GenServer
  def init({writer_buffer, metrics}) do
    Process.flag(:trap_exit, true)
    groups = Enum.group_by(metrics, &{&1.event_name, &1.reporter_options})

    for {{event, _} = a, metrics} <- groups do
      id = {__MODULE__, a, self()}
      :telemetry.attach(id, event, &TelemetryUI.Reporter.handle_event/4, {writer_buffer, metrics})
    end

    {:ok, Map.keys(groups)}
  end

  @impl GenServer
  def terminate(_, events) do
    for event <- events, do: :telemetry.detach({__MODULE__, event, self()})

    :ok
  end

  def handle_event(_event_name, measurements, metadata, {writer_buffer, metrics}) do
    for metric <- metrics, keep?(metric, metadata) do
      event_name = cast_event_name(metric)
      value = extract_measurement(metric, measurements, metadata)
      tags = extract_tags(metric, metadata)

      TelemetryUI.insert_metric_data(
        writer_buffer,
        %TelemetryUI.Event{
          value: value,
          time: DateTime.utc_now(),
          event_name: event_name,
          tags: tags,
          cast_value: cast_reporter_cast_value(metric)
        }
      )
    end
  end

  defp keep?(%{keep: nil}, _metadata), do: true
  defp keep?(metric, metadata), do: metric.keep.(metadata)

  defp extract_measurement(metric, measurements, metadata) do
    case metric.measurement do
      fun when is_function(fun, 2) -> fun.(measurements, metadata)
      fun when is_function(fun, 1) -> fun.(measurements)
      key -> measurements[key]
    end
  end

  defp extract_tags(metric, metadata) do
    tag_values = metric.tag_values.(metadata)
    Map.take(tag_values, metric.tags)
  end
end
