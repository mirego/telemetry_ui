defmodule TelemetryUI.Web.Components.TimeSeries do
  import TelemetryUI.Web.VegaLite.Spec

  alias VegaLite, as: Vl

  def render(metric = %{telemetry_metric: %{tags: []}}, assigns, options) do
    source = source(metric, assigns)
    domain = [assigns.filters.from, assigns.filters.to]
    time_unit = fetch_time_unit(assigns.filters.from, assigns.filters.to)
    unit = to_unit(metric.unit)

    tooltip = [
      [field: "date", type: :temporal, title: "Date", time_unit: time_unit],
      [field: options.field, type: :quantitative, title: options.field_label, aggregate: options.aggregate, format: options.format]
    ]

    spec =
      assigns
      |> base_spec()
      |> Vl.data_from_url(source, name: "source")

    summary_chart =
      Vl.new()
      |> Vl.mark(:bar,
        align: "left",
        baseline: "line-bottom",
        tooltip: true,
        width: [band: 0.6],
        fill_opacity: 1,
        color: hd(assigns.theme.scale),
        corner_radius_end: 2
      )
      |> encode_tags_color(metric.telemetry_metric)
      |> Vl.encode_field(:x, "date", type: :temporal, title: nil, time_unit: [unit: time_unit], scale: [domain: domain])
      |> Vl.encode_field(:y, options.field, type: :quantitative, title: nil, aggregate: options.aggregate)
      |> Vl.encode(:tooltip, tooltip)

    spec
    |> Vl.layers([aggregate_text_spec(options, unit), summary_chart])
    |> TelemetryUI.Web.VegaLite.draw(metric)
  end

  def render(metric, assigns, options) do
    source = source(metric, assigns)
    domain = [assigns.filters.from, assigns.filters.to]
    time_unit = fetch_time_unit(assigns.filters.from, assigns.filters.to)
    unit = to_unit(metric.unit)

    tooltip = [
      [field: "date", type: :temporal, title: "Date", time_unit: time_unit],
      [field: options.field, type: :quantitative, title: options.field_label, aggregate: options.aggregate, format: options.format],
      [field: "tags", title: "Tags"]
    ]

    spec =
      assigns
      |> base_spec()
      |> Vl.data_from_url(source, name: "source")

    summary_chart =
      Vl.new()
      |> Vl.mark(:area,
        align: "left",
        baseline: "line-bottom",
        point: [size: 14],
        line: [stroke_width: 1],
        tooltip: true,
        fill_opacity: 0.3,
        color: hd(assigns.theme.scale)
      )
      |> encode_tags_color(metric.telemetry_metric)
      |> Vl.encode_field(:x, "date", type: :temporal, title: nil, time_unit: [unit: time_unit], scale: [domain: domain])
      |> Vl.encode_field(:y, options.field, type: :quantitative, title: nil, aggregate: options.aggregate)
      |> Vl.encode(:tooltip, tooltip)

    spec
    |> Vl.layers([aggregate_text_spec(options, unit), summary_chart])
    |> TelemetryUI.Web.VegaLite.draw(metric)
  end

  defp aggregate_text_spec(options, unit) do
    Vl.new()
    |> Vl.mark(:text,
      font_size: 12,
      font_weight: "bold",
      baseline: "top",
      align: "right",
      color: "#666",
      x: "width",
      y: -30
    )
    |> Vl.transform(
      aggregate: [
        [op: options.aggregate, field: options.field, as: "aggregate_value"],
        [op: "max", field: "date", as: "to_date"],
        [op: "min", field: "date", as: "from_date"]
      ]
    )
    |> Vl.transform(
      calculate: "'#{options.aggregate_label}: ' + format(datum.aggregate_value#{options.aggregate_value_suffix}, '#{options.format}') + '#{unit}'",
      as: "formatted_aggregate_value"
    )
    |> Vl.encode(:text, field: "formatted_aggregate_value")
    |> Vl.encode(:tooltip, [
      [field: "from_date", title: "From", type: :temporal, time_unit: [unit: "yearmonthdatehoursminutes"]],
      [field: "to_date", title: "To", type: :temporal, time_unit: [unit: "yearmonthdatehoursminutes"]]
    ])
  end
end
