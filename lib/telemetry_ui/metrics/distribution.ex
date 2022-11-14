defmodule TelemetryUI.Metrics.Distribution do
  @moduledoc false

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
      metric
      |> Components.Buckets.spec(assigns, @options)
      |> TelemetryUI.Web.VegaLite.draw(metric)
    end
  end
end
