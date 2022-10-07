defmodule TelemetryUI.Metrics.Summary do
  use TelemetryUI.Metrics

  defimpl TelemetryUI.Web.Component do
    alias TelemetryUI.Web.Components
    alias TelemetryUI.Web.VegaLite.Spec

    @options %Spec.Options{
      field: "value",
      field_label: "Value",
      aggregate: "average",
      aggregate_label: "Average",
      format: ".2f"
    }

    def render(metric, assigns) do
      Components.TimeSeries.render(metric, assigns, @options)
    end

    def metric_data(metric, params) do
      {:async, fn -> TelemetryUI.metric_data(metric, params) end}
    end
  end
end
