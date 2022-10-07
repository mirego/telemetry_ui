defmodule TelemetryUI.Metrics.Counter do
  use TelemetryUI.Metrics

  defimpl TelemetryUI.Web.Component do
    alias TelemetryUI.Web.Components
    alias TelemetryUI.Web.VegaLite.Spec

    @options %Spec.Options{
      field: "count",
      field_label: "Count",
      aggregate: "sum",
      format: ""
    }

    def render(metric, assigns) do
      Components.Stat.render(metric, assigns, @options)
    end

    def metric_data(metric, params) do
      {:async, fn -> TelemetryUI.metric_data(metric, params) end}
    end
  end
end
