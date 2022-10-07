defmodule TelemetryUI.Metrics.CountOverTime do
  use TelemetryUI.Metrics

  defimpl TelemetryUI.Web.Component do
    alias TelemetryUI.Web.Components
    alias TelemetryUI.Web.VegaLite.Spec

    @options %Spec.Options{
      field: "count",
      field_label: "Count",
      aggregate: "sum",
      aggregate_label: "Total",
      format: ""
    }

    def render(metric, assigns) do
      Components.TimeSeries.render(metric, assigns, @options)
    end

    def metric_data(metric, params) do
      {:async, fn -> TelemetryUI.metric_data(metric, params) end}
    end
  end
end
