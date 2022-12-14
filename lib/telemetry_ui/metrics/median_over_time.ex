defmodule TelemetryUI.Metrics.MedianOverTime do
  @moduledoc false

  use TelemetryUI.Metrics

  defimpl TelemetryUI.Web.Component do
    alias TelemetryUI.Web.Components
    alias TelemetryUI.Web.VegaLite.Spec

    @options %Spec.Options{
      field: "value",
      field_label: "Value",
      aggregate_field: "value",
      aggregate: "median",
      aggregate_label: "Median",
      format: ".2f"
    }

    def render(metric, assigns) do
      metric
      |> Components.TimeSeries.spec(assigns, @options)
      |> TelemetryUI.Web.VegaLite.draw(metric)
    end
  end
end
