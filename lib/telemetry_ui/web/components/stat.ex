defmodule TelemetryUI.Web.Components.Stat do
  @moduledoc false

  import TelemetryUI.Web.VegaLite.Spec

  alias TelemetryUI.Web.Components.CompareAggregate
  alias VegaLite, as: Vl

  def spec(%{tags: []} = metric, assigns) do
    options = assigns.options
    time_unit = fetch_time_unit(assigns.filters.from, assigns.filters.to)
    unit = to_unit(metric.unit)
    chart_offset = 80

    tooltip = [
      [field: "date", type: :temporal, title: "Date", time_unit: time_unit],
      [field: options.field, type: :quantitative, title: options.field_label, aggregate: options.summary_aggregate || options.aggregate, format: options.format]
    ]

    compare_layer =
      options
      |> CompareAggregate.spec()
      |> Vl.mark(:text, font: "monospace", fill_opacity: 0.8, font_size: 13, x: "width", y: 0, align: "right", fill: [expr: CompareAggregate.fill_expression(metric)])

    assigns
    |> base_spec(height: 90)
    |> data_from_metric(metric, assigns)
    |> Vl.param("date_domain", value: [])
    |> Vl.layers([
      title(metric),
      Vl.new()
      |> Vl.transform(filter: "datum.compare==0")
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
      |> Vl.mark(:text, font_size: 30, font_weight: "bold", color: hd(assigns.theme.scale), x: 0, y: 30, align: "left")
      |> Vl.encode(:text, type: :nominal, field: "formatted_aggregate_value")
      |> Vl.encode(:tooltip, [
        [field: "from_date", title: "From", type: :temporal, time_unit: [unit: "yearmonthdatehoursminutes"]],
        [field: "to_date", title: "To", type: :temporal, time_unit: [unit: "yearmonthdatehoursminutes"]]
      ]),
      compare_layer,
      Vl.new()
      |> Vl.transform(filter: "datum.compare==0")
      |> Vl.mark(:area,
        opacity: 0.2,
        interpolate: "monotone",
        tooltip: true,
        color: hd(assigns.theme.scale),
        y_offset: chart_offset,
        y2_offset: chart_offset,
        y2: [expr: "height + #{chart_offset}"]
      )
      |> Vl.encode(:tooltip, tooltip)
      |> Vl.encode_field(:x, "date", type: :temporal, title: nil, axis: nil, time_unit: [unit: time_unit])
      |> Vl.encode_field(:y, options.field, type: :quantitative, title: nil, axis: nil, aggregate: options.summary_aggregate || options.aggregate),
      Vl.new()
      |> Vl.transform(filter: "datum.compare==0")
      |> Vl.mark(:line, opacity: 0.3, interpolate: "monotone", color: hd(assigns.theme.scale), y_offset: chart_offset, y2_offset: chart_offset)
      |> Vl.encode_field(:x, "date", type: :temporal, title: nil, axis: nil, time_unit: [unit: time_unit])
      |> Vl.encode_field(:y, options.field, type: :quantitative, title: nil, axis: nil, aggregate: options.summary_aggregate || options.aggregate)
    ])
  end

  def spec(metric, assigns) do
    options = assigns.options
    chart_offset = 80

    assigns
    |> base_spec(height: 130)
    |> data_from_metric(metric, assigns)
    |> Vl.param("date_domain", value: [])
    |> Vl.layers([
      title(metric, y: -20),
      Vl.new()
      |> Vl.transform(filter: "datum.compare==0")
      |> Vl.transform(aggregate: [[op: options.aggregate, field: options.field, as: "aggregate_value"]], groupby: ["tags"])
      |> Vl.encode_field(:x, "tags", sort: "-y", type: :nominal, title: nil, axis: [label_angle: -30])
      |> Vl.encode_field(:color, "tags", title: nil, legend: nil)
      |> Vl.param("tags", select: [fields: ["tags"], type: :point], bind: "legend")
      |> Vl.encode(:opacity, value: 0.2, condition: [param: "tags", value: 1, empty: true])
      |> Vl.encode_field(:y, "aggregate_value#{options.aggregate_value_suffix}", type: :quantitative, title: nil)
      |> Vl.mark(:bar, width: [band: 0.6], corner_radius_end: 2, y: chart_offset)
      |> Vl.encode(:tooltip, [
        [field: "aggregate_value#{options.aggregate_value_suffix}", type: :quantitative, title: options.field_label, aggregate: options.aggregate, format: options.format]
      ])
    ])
  end
end
