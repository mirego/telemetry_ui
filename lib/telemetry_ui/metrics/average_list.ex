defmodule TelemetryUI.Metrics.AverageList do
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
      format: ".2f",
      legend: false
    }

    def to_image(metric, extension, assigns) do
      spec = Components.StatList.spec(metric, assigns, @options)
      spec = VegaLite.Export.to_json(spec)
      TelemetryUI.VegaLiteToImage.export(spec, extension)
    end

    def to_html(metric, assigns) do
      assigns = %{assigns | options: @options}

      metric
      |> Components.StatList.spec(assigns, @options)
      |> TelemetryUI.Web.VegaLite.draw(metric, assigns)
    end
  end
end
