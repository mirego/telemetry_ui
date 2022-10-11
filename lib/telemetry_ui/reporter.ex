defmodule TelemetryUI.Reporter do
  @moduledoc false

  import TelemetryUI.Event

  use GenServer
  require Logger

  def start_link(opts) do
    server_opts = Keyword.take(opts, [:name])

    metrics =
      opts[:metrics] ||
        raise ArgumentError, "the :metrics option is required by #{inspect(__MODULE__)}"

    GenServer.start_link(__MODULE__, metrics, server_opts)
  end

  @impl true
  def init(metrics) do
    Process.flag(:trap_exit, true)
    groups = Enum.group_by(metrics, &{&1.event_name, &1.reporter_options})

    for {{event, _} = a, metrics} <- groups do
      id = {__MODULE__, a, self()}
      :telemetry.attach(id, event, &TelemetryUI.Reporter.handle_event/4, metrics)
    end

    {:ok, Map.keys(groups)}
  end

  @impl true
  def terminate(_, events) do
    for event <- events, do: :telemetry.detach({__MODULE__, event, self()})

    :ok
  end

  def handle_event(_event_name, measurements, metadata, metrics) do
    for metric <- metrics, keep?(metric, metadata) do
      event_name = cast_event_name(metric)
      value = extract_measurement(metric, measurements, metadata)
      tags = extract_tags(metric, metadata)

      TelemetryUI.WriteBuffer.insert(%TelemetryUI.Event{
        value: value,
        time: DateTime.utc_now(),
        event_name: event_name,
        tags: tags,
        report_as: cast_report_as(metric)
      })
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
