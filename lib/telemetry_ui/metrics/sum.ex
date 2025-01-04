defmodule TelemetryUI.Metrics.Sum do
  @moduledoc false

  use TelemetryUI.Metrics

  defimpl TelemetryUI.Web.Component do
    alias TelemetryUI.Web.Components
    alias TelemetryUI.Web.VegaLite.Spec

    @options %Spec.Options{
      field: "value",
      field_label: "Value",
      aggregate: "sum"
    }

    def to_image(metric, assigns) do
      assigns = TelemetryUI.Metrics.merge_assigns_options(assigns, @options)

      metric
      |> Components.Stat.spec(assigns)
      |> VegaLite.Convert.to_png()
    end

    def to_html(metric, assigns) do
      assigns = TelemetryUI.Metrics.merge_assigns_options(assigns, @options)

      metric
      |> Components.Stat.spec(assigns)
      |> TelemetryUI.Web.VegaLite.draw(metric, assigns)
    end
  end
end
