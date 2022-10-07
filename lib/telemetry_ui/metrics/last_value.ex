defmodule TelemetryUI.Metrics.LastValue do
  use TelemetryUI.Metrics

  defimpl TelemetryUI.Web.Component do
    alias TelemetryUI.Web.Components
    alias TelemetryUI.Web.VegaLite.Spec

    @options %Spec.Options{
      field: "value",
      field_label: "Value",
      summary_aggregate: "average",
      aggregate_field: "date",
      aggregate: "argmax",
      format: ".2f",
      aggregate_value_suffix: "['value']"
    }

    def render(metric, assigns) do
      Components.Stat.render(metric, assigns, @options)
    end

    def metric_data(metric, params) do
      {:async, fn -> TelemetryUI.metric_data(metric, params) end}
    end
  end
end
