defmodule TelemetryUI.Metrics.LastValue do
  @moduledoc false

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

    def to_image(metric, extension, assigns) do
      assigns = TelemetryUI.Metrics.merge_assigns_options(assigns, @options)

      metric
      |> Components.Stat.spec(assigns)
      |> VegaLite.Export.to_json()
      |> TelemetryUI.VegaLiteToImage.export(extension)
    end

    def to_html(metric, assigns) do
      assigns = TelemetryUI.Metrics.merge_assigns_options(assigns, @options)

      metric
      |> Components.Stat.spec(assigns)
      |> TelemetryUI.Web.VegaLite.draw(metric, assigns)
    end
  end
end
