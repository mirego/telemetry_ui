defmodule TelemetryUI.Metrics.Average do
  @moduledoc false

  use TelemetryUI.Metrics

  defimpl TelemetryUI.Web.Component do
    alias TelemetryUI.Web.Components
    alias TelemetryUI.Web.VegaLite.Spec

    @options %Spec.Options{
      field: "value",
      field_label: "Value",
      summary_aggregate: "average",
      aggregate_field: "value",
      aggregate: "average",
      format: ".2f"
    }

    def render(metric, assigns) do
      metric
      |> Components.Stat.spec(assigns, @options)
      |> TelemetryUI.Web.VegaLite.draw(metric)
    end
  end
end
