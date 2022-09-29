defmodule TelemetryUI.Metrics do
  alias Telemetry.Metrics
  alias TelemetryUI.Event
  alias TelemetryUI.Web.Component.VegaLite

  defmodule Summary do
    defstruct id: nil, title: nil, telemetry_metric: nil, web_component: nil, data: nil, unit: nil
  end

  defmodule Counter do
    defstruct id: nil, title: nil, telemetry_metric: nil, web_component: nil, data: nil, unit: nil
  end

  defmodule Sum do
    defstruct id: nil, title: nil, telemetry_metric: nil, web_component: nil, data: nil, unit: nil
  end

  defmodule LastValue do
    defstruct id: nil, title: nil, telemetry_metric: nil, web_component: nil, data: nil, unit: nil
  end

  @telemetry_metrics [
    {:summary, Summary},
    {:counter, Counter},
    {:sum, Sum},
    {:last_value, LastValue}
  ]

  for {metric_name, metric_struct} <- @telemetry_metrics do
    def unquote(metric_name)(event_name, options) do
      {ui_options, options} = Keyword.pop(options, :ui_options, [])
      metric = apply(Metrics, unquote(metric_name), [event_name, options])
      web_component = Keyword.get_lazy(ui_options, :web_component, fn -> %VegaLite{} end)

      unit =
        case Keyword.get(ui_options, :unit, metric.unit) do
          {_, unit} -> unit
          unit -> unit
        end

      struct!(unquote(metric_struct),
        id: id(metric),
        title: metric.description || Event.cast_event_name(metric),
        unit: unit,
        web_component: web_component,
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
