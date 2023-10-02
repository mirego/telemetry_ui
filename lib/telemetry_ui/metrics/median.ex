defmodule TelemetryUI.Metrics.Median do
  @moduledoc false

  use TelemetryUI.Metrics

  defimpl TelemetryUI.Web.Component do
    alias TelemetryUI.Web.Components
    alias TelemetryUI.Web.VegaLite.Spec

    @options %Spec.Options{
      field: "value",
      field_label: "Value",
      summary_aggregate: "median",
      aggregate_field: "value",
      aggregate: "median",
      format: ".2f"
    }

    def to_image(metric, extension, assigns) do
      spec = Components.Stat.spec(metric, assigns, @options)
      spec = VegaLite.Export.to_json(spec)
      TelemetryUI.VegaLiteToImage.export(spec, extension)
    end

    def to_html(metric, assigns) do
      assigns = %{assigns | options: @options}

      metric
      |> Components.Stat.spec(assigns, @options)
      |> TelemetryUI.Web.VegaLite.draw(metric, assigns)
    end
  end
end
