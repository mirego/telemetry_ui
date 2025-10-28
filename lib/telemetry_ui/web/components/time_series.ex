defmodule TelemetryUI.Web.Components.TimeSeries do
  @moduledoc false

  import TelemetryUI.Web.VegaLite.Spec

  alias TelemetryUI.Web.Components.CompareAggregate
  alias VegaLite, as: Vl

  def spec(%{tags: []} = metric, assigns) do
    options = assigns.options
    to = DateTime.to_unix(DateTime.add(assigns.filters.to, 60, :second), :millisecond)
    from = DateTime.to_unix(assigns.filters.from, :millisecond)
    time_unit = fetch_time_unit(assigns.filters.from, assigns.filters.to)
    unit = to_unit(metric.unit)

    tooltip = [
      [field: "date", type: :temporal, title: "Date", time_unit: time_unit],
      [field: options.field, type: :quantitative, title: options.field_label, aggregate: options.aggregate, format: options.format]
    ]

    spec =
      assigns
      |> base_spec(height: 130)
      |> data_from_metric(metric, assigns)
      |> Vl.param("date_domain", value: [from, to])

    summary_chart =
      Vl.new()
      |> Vl.transform(filter: "datum.compare==0 || datum.compare == null")
      |> Vl.mark(:bar,
        clip: true,
        align: "left",
        baseline: "line-bottom",
        interpolate: "monotone",
        tooltip: true,
        fill_opacity: 1,
        color: hd(assigns.theme.scale),
        corner_radius_end: 2
      )
      |> Vl.transform(filter: "datum.compare==0 || datum.compare == null")
      |> Vl.encode_field(:x, "date", type: :temporal, title: nil, time_unit: [unit: time_unit], scale: [domain: [expr: "date_domain"]])
      |> Vl.encode_field(:y, options.field, type: :quantitative, title: nil, aggregate: options.aggregate, format: options.format)
      |> Vl.encode(:tooltip, tooltip)

    Vl.layers(spec, [title(metric, y: -24), compare_aggregate_text_spec(options, metric), aggregate_text_spec(options, unit), summary_chart])
  end

  def spec(metric, assigns) do
    options = assigns.options
    to = DateTime.to_unix(DateTime.add(assigns.filters.to, 60, :second), :millisecond)
    from = DateTime.to_unix(assigns.filters.from, :millisecond)
    time_unit = fetch_time_unit(assigns.filters.from, assigns.filters.to)
    unit = to_unit(metric.unit)

    tooltip = [
      [field: "date", type: :temporal, title: "Date", time_unit: time_unit],
      [field: options.field, type: :quantitative, title: options.field_label, aggregate: options.aggregate, format: options.format],
      [field: "tags", title: "Tags"]
    ]

    spec =
      assigns
      |> base_spec(height: 130)
      |> data_from_metric(metric, assigns)
      |> Vl.param("date_domain", value: [from, to])

    summary_chart =
      Vl.new()
      |> Vl.transform(filter: "datum.compare==0 || datum.compare == null")
      |> Vl.mark(:area,
        clip: true,
        align: "left",
        interpolate: "monotone",
        baseline: "line-bottom",
        point: [size: 14],
        line: [stroke_width: 1, stroke_opacity: 0.8],
        tooltip: true,
        fill_opacity: 0.3,
        color: hd(assigns.theme.scale)
      )
      |> Vl.transform(filter: "datum.compare==0 || datum.compare == null")
      |> encode_tags_color(metric.tags)
      |> Vl.encode_field(:x, "date", type: :temporal, title: nil, time_unit: [unit: time_unit], scale: [domain: [expr: "date_domain"]])
      |> Vl.encode_field(:y, options.field, type: :quantitative, title: nil, aggregate: options.aggregate, stack: nil, format: options.format)
      |> Vl.param("tags", select: [fields: ["tags"], type: :point], bind: "legend")
      |> Vl.encode(:opacity, value: 0, condition: [param: "tags", value: 1, empty: true])
      |> Vl.encode(:tooltip, tooltip)

    Vl.layers(spec, [title(metric, y: -24), compare_aggregate_text_spec(options, metric), aggregate_text_spec(options, unit), summary_chart])
  end

  defp compare_aggregate_text_spec(options, metric) do
    options
    |> CompareAggregate.spec()
    |> Vl.mark(:text,
      font: "monospace",
      fill_opacity: 0.8,
      font_size: 11,
      x: "width",
      y: -8,
      align: "right",
      fill: [expr: CompareAggregate.fill_expression(metric)]
    )
  end

  defp aggregate_text_spec(options, unit) do
    Vl.new()
    |> Vl.transform(filter: "datum.compare==0 || datum.compare == null")
    |> Vl.mark(:text,
      font_size: 11,
      font_weight: "bold",
      baseline: "top",
      align: "right",
      color: "#666",
      x: "width",
      y: -28
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
    |> Vl.transform(calculate: "toDate(datum.from_date)", as: "from_date")
    |> Vl.transform(calculate: "toDate(datum.to_date)", as: "to_date")
    |> Vl.encode(:tooltip, [
      [field: "from_date", title: "From", type: :temporal, time_unit: [unit: "yearmonthdatehoursminutes"]],
      [field: "to_date", title: "To", type: :temporal, time_unit: [unit: "yearmonthdatehoursminutes"]]
    ])
  end
end
