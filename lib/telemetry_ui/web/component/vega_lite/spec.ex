defmodule TelemetryUI.Web.Component.VegaLite.Spec do
  @moduledoc false

  alias TelemetryUI.Metrics
  alias VegaLite, as: Vl

  def build(metric = %Metrics.Summary{}, data, assigns) do
    domain = [assigns.filters.from, assigns.filters.to]
    time_unit = fetch_time_unit(assigns.filters.from, assigns.filters.to)

    value_field = Keyword.get(metric.telemetry_metric.reporter_options, :value_field, "value")
    value_label = value_field_to_title(value_field, metric)
    aggregate_label = if value_field === "value", do: "Average", else: "Total"
    aggregate = if value_field === "value", do: "average", else: "sum"
    format = if value_field === "value", do: ".2f", else: ""
    unit = if value_field === "value", do: to_unit(metric.unit), else: ""

    tooltip = [
      [field: "date", type: :temporal, title: "Date", time_unit: time_unit],
      [field: value_field, type: :quantitative, title: value_label, aggregate: aggregate, format: format]
    ]

    tooltip = if metric.telemetry_metric.tags === [], do: tooltip, else: tooltip ++ [[field: "tags", title: "Tags"]]
    mark = if metric.telemetry_metric.tags === [], do: :bar, else: :area
    fill_opacity = if mark === :bar, do: 1, else: 0.3

    spec =
      assigns
      |> base_spec()
      |> Vl.data_from_url(data.source, name: "source")

    summary_chart =
      Vl.new()
      |> Vl.mark(mark,
        align: "left",
        baseline: "line-bottom",
        point: [size: 14],
        line: [stroke_width: 1],
        tooltip: true,
        width: [band: 0.6],
        fill_opacity: fill_opacity,
        color: hd(assigns.theme.scale),
        corner_radius_end: 2
      )
      |> encode_tags_color(metric.telemetry_metric)
      |> Vl.encode_field(:x, "date", type: :temporal, title: nil, time_unit: [unit: time_unit], scale: [domain: domain])
      |> Vl.encode_field(:y, value_field, type: :quantitative, title: nil, aggregate: aggregate)
      |> Vl.encode(:tooltip, tooltip)

    aggregate_text =
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
          [op: aggregate, field: value_field, as: "aggregate_value"],
          [op: "max", field: "date", as: "to_date"],
          [op: "min", field: "date", as: "from_date"]
        ]
      )
      |> Vl.transform(calculate: "'#{aggregate_label}: ' + format(datum.aggregate_value, '#{format}') + '#{unit}'", as: "formatted_aggregate_value")
      |> Vl.encode(:text, field: "formatted_aggregate_value")
      |> Vl.encode(:tooltip, [
        [field: "from_date", title: "From", type: :temporal, time_unit: [unit: "yearmonthdatehoursminutes"]],
        [field: "to_date", title: "To", type: :temporal, time_unit: [unit: "yearmonthdatehoursminutes"]]
      ])

    Vl.layers(spec, [aggregate_text, summary_chart])
  end

  def build(metric = %Metrics.Sum{telemetry_metric: %{tags: []}}, data, assigns) do
    domain = [assigns.filters.from, assigns.filters.to]
    time_unit = fetch_time_unit(assigns.filters.from, assigns.filters.to)
    value_field = Keyword.get(metric.telemetry_metric.reporter_options, :value_field, "value")
    value_label = value_field_to_title(value_field, metric)
    aggregate = if value_field === "value", do: "average", else: "sum"
    format = if value_field === "value", do: ".2f", else: ""
    unit = to_unit(metric.unit)

    tooltip = [
      [field: "date", type: :temporal, title: "Date", time_unit: time_unit],
      [field: value_field, type: :quantitative, title: value_label, aggregate: aggregate, format: format]
    ]

    assigns
    |> base_spec(height: 40)
    |> Vl.data_from_url(data.source, name: "source")
    |> Vl.layers([
      Vl.new()
      |> Vl.transform(aggregate: [[op: "sum", field: "value", as: "aggregate_value"]])
      |> Vl.transform(calculate: "format(datum.aggregate_value, '#{format}') + ' #{unit}'", as: "formatted_aggregate_value")
      |> Vl.mark(:text, font_size: 50, font_weight: "bold", color: hd(assigns.theme.scale), x: 0, y: 0)
      |> Vl.encode(:text, type: :nominal, field: "formatted_aggregate_value", format: format),
      Vl.new()
      |> Vl.mark(:area, opacity: 0.2, tooltip: true, color: hd(assigns.theme.scale), y_offset: 40, y2_offset: 40, y2: [expr: "height + 40"])
      |> Vl.encode(:tooltip, tooltip)
      |> Vl.encode_field(:x, "date", type: :temporal, title: nil, axis: nil, time_unit: [unit: time_unit], scale: [domain: domain])
      |> Vl.encode_field(:y, "value", type: :quantitative, title: nil, axis: nil, aggregate: aggregate, format: format),
      Vl.new()
      |> Vl.mark(:line, opacity: 0.3, color: hd(assigns.theme.scale), y_offset: 40, y2_offset: 40)
      |> Vl.encode_field(:x, "date", type: :temporal, title: nil, axis: nil, time_unit: [unit: time_unit], scale: [domain: domain])
      |> Vl.encode_field(:y, "value", type: :quantitative, title: nil, axis: nil, aggregate: aggregate)
    ])
  end

  def build(metric = %Metrics.Counter{telemetry_metric: %{tags: []}}, data, assigns) do
    domain = [assigns.filters.from, assigns.filters.to]
    time_unit = fetch_time_unit(assigns.filters.from, assigns.filters.to)
    value_field = Keyword.get(metric.telemetry_metric.reporter_options, :value_field, "count")
    value_label = value_field_to_title(value_field, metric)
    aggregate = if value_field === "value", do: "average", else: "sum"
    format = if value_field === "value", do: ".2f", else: ""
    unit = to_unit(metric.unit)

    tooltip = [
      [field: "date", type: :temporal, title: "Date", time_unit: time_unit],
      [field: value_field, type: :quantitative, title: value_label, aggregate: "sum"]
    ]

    assigns
    |> base_spec(height: 40)
    |> Vl.data_from_url(data.source, name: "source")
    |> Vl.layers([
      Vl.new()
      |> Vl.transform(aggregate: [[op: aggregate, field: value_field, as: "aggregate_value"]])
      |> Vl.transform(calculate: "format(datum.aggregate_value, '#{format}') + ' #{unit}'", as: "formatted_aggregate_value")
      |> Vl.mark(:text, font_size: 50, font_weight: "bold", color: hd(assigns.theme.scale), x: 0, y: 0)
      |> Vl.encode(:text, type: :nominal, field: "formatted_aggregate_value"),
      Vl.new()
      |> Vl.mark(:area, opacity: 0.2, tooltip: true, color: hd(assigns.theme.scale), y_offset: 40, y2_offset: 40, y2: [expr: "height + 40"])
      |> Vl.encode(:tooltip, tooltip)
      |> Vl.encode_field(:x, "date", type: :temporal, title: nil, axis: nil, time_unit: [unit: time_unit], scale: [domain: domain])
      |> Vl.encode_field(:y, value_field, type: :quantitative, title: nil, axis: nil, aggregate: aggregate),
      Vl.new()
      |> Vl.mark(:line, opacity: 0.3, color: hd(assigns.theme.scale), y_offset: 40, y2_offset: 40)
      |> Vl.encode_field(:x, "date", type: :temporal, title: nil, axis: nil, time_unit: [unit: time_unit], scale: [domain: domain])
      |> Vl.encode_field(:y, value_field, type: :quantitative, title: nil, axis: nil, aggregate: aggregate)
    ])
  end

  def build(metric = %Metrics.LastValue{telemetry_metric: %{tags: []}}, data, assigns) do
    domain = [assigns.filters.from, assigns.filters.to]
    time_unit = fetch_time_unit(assigns.filters.from, assigns.filters.to)
    value_field = Keyword.get(metric.telemetry_metric.reporter_options, :value_field, "value")
    value_label = value_field_to_title(value_field, metric)
    aggregate = if value_field === "value", do: "average", else: "sum"
    format = if value_field === "value", do: ".2f", else: ""
    unit = if value_field === "value", do: to_unit(metric.unit), else: ""

    tooltip = [
      [field: "date", type: :temporal, title: "Date", time_unit: time_unit],
      [field: value_field, type: :quantitative, title: value_label, aggregate: aggregate, format: format]
    ]

    assigns
    |> base_spec(height: 40)
    |> Vl.data_from_url(data.source, name: "source")
    |> Vl.layers([
      Vl.new()
      |> Vl.transform(aggregate: [[op: "argmax", field: "date", as: "argmax_date"]])
      |> Vl.transform(calculate: "format(datum.argmax_date['value'], '#{format}') + ' #{unit}'", as: "formatted_aggregate_value")
      |> Vl.mark(:text, font_size: 50, font_weight: "bold", color: hd(assigns.theme.scale), x: 0, y: 0)
      |> Vl.encode(:text, type: :nominal, field: "formatted_aggregate_value"),
      Vl.new()
      |> Vl.mark(:area, opacity: 0.2, tooltip: true, color: hd(assigns.theme.scale), y_offset: 40, y2_offset: 40, y2: [expr: "height + 40"])
      |> Vl.encode(:tooltip, tooltip)
      |> Vl.encode_field(:x, "date", type: :temporal, title: nil, axis: nil, time_unit: [unit: time_unit], scale: [domain: domain])
      |> Vl.encode_field(:y, value_field, type: :quantitative, title: nil, axis: nil, aggregate: aggregate),
      Vl.new()
      |> Vl.mark(:line, opacity: 0.3, color: hd(assigns.theme.scale), y_offset: 40)
      |> Vl.encode_field(:x, "date", type: :temporal, title: nil, axis: nil, time_unit: [unit: time_unit], scale: [domain: domain])
      |> Vl.encode_field(:y, value_field, type: :quantitative, title: nil, axis: nil, aggregate: aggregate)
    ])
  end

  def build(%Metrics.Sum{}, data, assigns) do
    spec =
      assigns
      |> base_spec()
      |> Vl.data_from_url(data.source, name: "source")
      |> Vl.transform(aggregate: [[op: "sum", field: "value", as: "aggregate_value"]], groupby: ["tags"])
      |> Vl.encode_field(:x, "tags", type: :nominal, title: nil, axis: [label_angle: -30])
      |> Vl.encode_field(:color, "tags", title: nil, legend: nil)
      |> Vl.encode_field(:y, "aggregate_value", type: :quantitative, title: nil)

    Vl.layers(spec, [
      Vl.new()
      |> Vl.mark(:bar, width: [band: 0.6], corner_radius_end: 2)
      |> Vl.encode(:tooltip, [[field: "aggregate_value", type: :quantitative, title: "Value", aggregate: "average", format: ".2f"]])
    ])
  end

  def build(%Metrics.Counter{}, data, assigns) do
    spec =
      assigns
      |> base_spec()
      |> Vl.data_from_url(data.source, name: "source")
      |> Vl.transform(aggregate: [[op: "sum", field: "count", as: "aggregate_value"]], groupby: ["tags"])
      |> Vl.encode_field(:x, "tags", type: :nominal, title: nil, axis: [label_angle: -30])
      |> Vl.encode_field(:color, "tags", title: nil, legend: nil)
      |> Vl.encode_field(:y, "aggregate_value", type: :quantitative, title: nil)

    Vl.layers(spec, [
      Vl.new()
      |> Vl.mark(:bar, width: [band: 0.6], corner_radius_end: 2)
      |> Vl.encode(:tooltip, [[field: "aggregate_value", type: :quantitative, title: "Count", aggregate: "sum"]])
    ])
  end

  def build(%Metrics.LastValue{}, data, assigns) do
    spec =
      assigns
      |> base_spec()
      |> Vl.data_from_url(data.source, name: "source")
      |> Vl.transform(aggregate: [[op: "argmax", field: "date", as: "argmax_date"]], groupby: ["tags"])
      |> Vl.encode_field(:x, "tags", type: :nominal, title: nil, axis: [label_angle: -30])
      |> Vl.encode_field(:color, "tags", title: nil, legend: nil)
      |> Vl.encode_field(:y, "argmax_date['value']", type: :quantitative, title: nil)

    Vl.layers(spec, [
      Vl.new()
      |> Vl.mark(:bar, width: [band: 0.6], corner_radius_end: 2)
      |> Vl.encode(:tooltip, [[field: "argmax_date['value']", type: :quantitative, title: "Value", aggregate: "sum"]])
    ])
  end

  def build(_, _, _), do: :not_supported

  defp value_field_to_title("value", metric), do: "Value (#{to_unit(metric.unit)})"
  defp value_field_to_title(label, _), do: Phoenix.Naming.camelize(label)

  defp to_unit(:millisecond), do: "ms"
  defp to_unit(:megabyte), do: "mb"
  defp to_unit(unit), do: unit

  defp fetch_time_unit(from, to) do
    case DateTime.diff(to, from) do
      diff when diff <= 43_200 -> "yearmonthdatehoursminutes"
      diff when diff <= 691_200 -> "yearmonthdatehours"
      _ -> "yearmonthdate"
    end
  end

  defp base_spec(assigns, config \\ []) do
    grid_color = "rgba(0,0,0,0.1)"
    label_color = "#666"
    config = Keyword.merge([width: "container", height: 100, background: "transparent"], config)

    Vl.config(
      Vl.new(config),
      axis_y: [domain_color: label_color, label_color: label_color, tick_color: label_color, grid_color: grid_color],
      axis_x: [domain_color: label_color, label_color: label_color, tick_color: label_color, grid_color: grid_color],
      view: [stroke: nil],
      range: [category: assigns.theme.scale]
    )
  end

  defp encode_tags_color(spec, metric) do
    if Enum.any?(metric.tags) do
      Vl.encode_field(spec, :color, "tags", title: nil, legend: nil)
    else
      spec
    end
  end
end
