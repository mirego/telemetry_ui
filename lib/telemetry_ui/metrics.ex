defmodule TelemetryUI.Metrics do
  alias Telemetry.Metrics
  alias TelemetryUI.Event
  alias TelemetryUI.Web.Component.VegaLite

  defstruct id: nil, title: nil, telemetry_metric: nil, web_component: nil

  @telemetry_metrics ~w(
    summary
    counter
    sum
    last_value
  )a

  for metric_name <- @telemetry_metrics do
    def unquote(metric_name)(event_name, options) do
      {ui_options, options} = Keyword.pop(options, :ui_options, [])
      metric = apply(Metrics, unquote(metric_name), [event_name, options])
      web_component = Keyword.get_lazy(ui_options, :web_component, fn -> %VegaLite{metric: metric} end)

      %__MODULE__{
        id: id(metric),
        title: metric.description || Event.cast_event_name(metric),
        web_component: web_component,
        telemetry_metric: metric
      }
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
