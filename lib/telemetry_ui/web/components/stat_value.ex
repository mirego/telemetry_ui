defmodule TelemetryUI.Web.Components.StatValue do
  @moduledoc false

  import TelemetryUI.Web.VegaLite.Spec

  alias VegaLite, as: Vl

  def spec(%{tags: []} = metric, assigns) do
    options = assigns.options
    unit = to_unit(metric.unit)

    assigns
    |> base_spec(height: 70)
    |> data_from_metric(metric, assigns)
    |> Vl.param("date_domain", value: [])
    |> Vl.layers([
      title(metric, align: "left"),
      Vl.new()
      |> Vl.transform(
        aggregate: [
          [op: options.aggregate, field: options.aggregate_field || options.field, as: "aggregate_value"],
          [op: "max", field: "date", as: "to_date"],
          [op: "min", field: "date", as: "from_date"]
        ]
      )
      |> Vl.transform(calculate: "toDate(datum.from_date)", as: "from_date")
      |> Vl.transform(calculate: "toDate(datum.to_date)", as: "to_date")
      |> Vl.transform(calculate: "format(datum.aggregate_value#{options.aggregate_value_suffix}, '#{options.format}') + '#{unit}'", as: "formatted_aggregate_value")
      |> Vl.mark(:text, font_size: 50, font_weight: "bold", color: hd(assigns.theme.scale), x: 0, y: 46, align: "left")
      |> Vl.encode(:text, type: :nominal, field: "formatted_aggregate_value")
      |> Vl.encode(:tooltip, [
        [field: "from_date", title: "From", type: :temporal, time_unit: [unit: "yearmonthdatehoursminutes"]],
        [field: "to_date", title: "To", type: :temporal, time_unit: [unit: "yearmonthdatehoursminutes"]]
      ])
    ])
  end
end
