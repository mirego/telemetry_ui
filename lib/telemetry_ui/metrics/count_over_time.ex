defmodule TelemetryUI.Metrics.CountOverTime do
  @moduledoc false

  use TelemetryUI.Metrics

  defimpl TelemetryUI.Web.Component do
    alias TelemetryUI.Web.Components
    alias TelemetryUI.Web.VegaLite.Spec

    @options %Spec.Options{
      field: "count",
      field_label: "Count",
      aggregate: "sum",
      aggregate_label: "Total"
    }

    def to_image(metric, extension, assigns) do
      assigns = TelemetryUI.Metrics.merge_assigns_options(assigns, @options)

      metric
      |> Components.TimeSeries.spec(assigns)
      |> VegaLite.Export.to_json()
      |> TelemetryUI.VegaLiteToImage.export(extension)
    end

    def to_html(metric, assigns) do
      assigns = TelemetryUI.Metrics.merge_assigns_options(assigns, @options)

      metric
      |> Components.TimeSeries.spec(assigns)
      |> TelemetryUI.Web.VegaLite.draw(metric, assigns)
    end
  end
end
