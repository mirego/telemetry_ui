defmodule TelemetryUI.Metrics do
  alias Telemetry.Metrics
  alias TelemetryUI.Event
  alias TelemetryUI.Metrics, as: UIMetrics

  @telemetry_metrics [
    {:count_over_time, UIMetrics.CountOverTime},
    {:counter, UIMetrics.Counter},
    {:distribution, UIMetrics.Distribution},
    {:last_value, UIMetrics.LastValue},
    {:summary, UIMetrics.Summary},
    {:sum, UIMetrics.Sum},
    {:value_over_time, UIMetrics.ValueOverTime}
  ]

  defmacro __using__(_) do
    quote do
      defstruct id: nil, title: nil, telemetry_metric: nil, data: nil, unit: nil
    end
  end

  for {metric_name, metric_struct} <- @telemetry_metrics do
    def unquote(metric_name)(event_name, options) do
      {ui_options, options} = Keyword.pop(options, :ui_options, [])
      metric = Metrics.summary(event_name, options)

      unit =
        case Keyword.get(ui_options, :unit, metric.unit) do
          {_, unit} -> unit
          unit -> unit
        end

      struct!(unquote(metric_struct),
        id: id(metric),
        title: metric.description || Event.cast_event_name(metric),
        unit: unit,
        telemetry_metric: metric
      )
    end
  end

  defp id(metric) do
    reporter_options = Enum.map_join(Enum.into(metric.reporter_options, %{}), "|", fn {key, value} -> "#{key}:#{value}" end)

    [
      metric.description,
      metric.name,
      metric.tags,
      reporter_options
    ]
    |> List.flatten()
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("-")
    |> Base.url_encode64(padding: false)
  end
end
