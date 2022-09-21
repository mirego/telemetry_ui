defmodule TelemetryUI.Web.Component.VegaLiteSpec do
  @moduledoc false

  alias VegaLite, as: Vl

  def build(metric = %Telemetry.Metrics.Summary{}, data, assigns) do
    domain = [assigns.filters.from, assigns.filters.to]
    time_unit = fetch_time_unit(assigns.filters.from, assigns.filters.to)

    value_field = Keyword.get(metric.reporter_options, :value_field, "value")
    value_label = Phoenix.Naming.camelize(value_field)
    aggregate = if value_field === "value", do: "average", else: "sum"
    format = if value_field === "value", do: ".2f", else: ""

    tooltip = [
      [field: "date", type: :temporal, title: "Date", time_unit: time_unit],
      [field: value_field, type: :quantitative, title: value_label, aggregate: aggregate, format: format]
    ]

    tooltip = if metric.tags === [], do: tooltip, else: tooltip ++ [[field: "tags", title: "Tags"]]
    mark = if metric.tags === [], do: :bar, else: :line

    spec =
      assigns
      |> base_spec()
      |> Vl.data_from_url(data.source, name: "source")

    Vl.layers(spec, [
      Vl.new()
      |> Vl.mark(mark, point: true, tooltip: true, color: hd(assigns.theme.scale))
      |> encode_tags_color(metric)
      |> Vl.encode_field(:x, "date", type: :temporal, title: nil, time_unit: [unit: time_unit], scale: [domain: domain])
      |> Vl.encode_field(:y, value_field, type: :quantitative, title: nil, aggregate: aggregate)
      |> Vl.encode(:tooltip, tooltip)
    ])
  end

  def build(%Telemetry.Metrics.Sum{tags: []}, data, assigns) do
    domain = [assigns.filters.from, assigns.filters.to]
    time_unit = fetch_time_unit(assigns.filters.from, assigns.filters.to)

    tooltip = [
      [field: "date", type: :temporal, title: "Date", time_unit: time_unit],
      [field: "value", type: :quantitative, title: "Value", aggregate: "sum", format: ".2f"]
    ]

    spec =
      assigns
      |> base_spec()
      |> Vl.data_from_url(data.source, name: "source")

    Vl.layers(spec, [
      Vl.new()
      |> Vl.mark(:area, opacity: 0.3, tooltip: true, color: hd(assigns.theme.scale))
      |> Vl.encode(:tooltip, tooltip)
      |> Vl.encode_field(:x, "date", type: :temporal, title: nil, axis: nil, time_unit: [unit: time_unit], scale: [domain: domain])
      |> Vl.encode_field(:y, "value", type: :quantitative, title: nil, axis: nil, aggregate: "sum", format: ".2f"),
      Vl.new()
      |> Vl.mark(:line, opacity: 0.8, color: hd(assigns.theme.scale))
      |> Vl.encode_field(:x, "date", type: :temporal, title: nil, axis: nil, time_unit: [unit: time_unit], scale: [domain: domain])
      |> Vl.encode_field(:y, "value", type: :quantitative, title: nil, axis: nil, aggregate: "sum"),
      Vl.new()
      |> Vl.transform(aggregate: [[op: "sum", field: "value", as: "aggregate_value"]])
      |> Vl.mark(:text, font_size: 50, font_weight: "bold", color: hd(assigns.theme.scale))
      |> Vl.encode(:text, type: :nominal, field: "aggregate_value", format: ".2f")
    ])
  end

  def build(%Telemetry.Metrics.Counter{tags: []}, data, assigns) do
    domain = [assigns.filters.from, assigns.filters.to]
    time_unit = fetch_time_unit(assigns.filters.from, assigns.filters.to)

    tooltip = [
      [field: "date", type: :temporal, title: "Date", time_unit: time_unit],
      [field: "count", type: :quantitative, title: "Count", aggregate: "sum"]
    ]

    spec =
      assigns
      |> base_spec()
      |> Vl.data_from_url(data.source, name: "source")

    Vl.layers(spec, [
      Vl.new()
      |> Vl.mark(:area, opacity: 0.3, tooltip: true, color: hd(assigns.theme.scale))
      |> Vl.encode(:tooltip, tooltip)
      |> Vl.encode_field(:x, "date", type: :temporal, title: nil, axis: nil, time_unit: [unit: time_unit], scale: [domain: domain])
      |> Vl.encode_field(:y, "count", type: :quantitative, title: nil, axis: nil, aggregate: "sum"),
      Vl.new()
      |> Vl.mark(:line, opacity: 0.8, color: hd(assigns.theme.scale))
      |> Vl.encode_field(:x, "date", type: :temporal, title: nil, axis: nil, time_unit: [unit: time_unit], scale: [domain: domain])
      |> Vl.encode_field(:y, "count", type: :quantitative, title: nil, axis: nil, aggregate: "sum"),
      Vl.new()
      |> Vl.transform(aggregate: [[op: "sum", field: "count", as: "aggregate_count"]])
      |> Vl.mark(:text, font_size: 50, font_weight: "bold", color: hd(assigns.theme.scale))
      |> Vl.encode(:text, type: :nominal, field: "aggregate_count")
    ])
  end

  def build(%Telemetry.Metrics.LastValue{tags: []}, data, assigns) do
    domain = [assigns.filters.from, assigns.filters.to]
    time_unit = fetch_time_unit(assigns.filters.from, assigns.filters.to)

    tooltip = [
      [field: "date", type: :temporal, title: "Date", time_unit: time_unit],
      [field: "value", type: :quantitative, title: "Value", format: ".2f", aggregate: "average"]
    ]

    spec =
      assigns
      |> base_spec()
      |> Vl.data_from_url(data.source, name: "source")

    Vl.layers(spec, [
      Vl.new()
      |> Vl.mark(:area, opacity: 0.3, tooltip: true, color: hd(assigns.theme.scale))
      |> Vl.encode(:tooltip, tooltip)
      |> Vl.encode_field(:x, "date", type: :temporal, title: nil, axis: nil, time_unit: [unit: time_unit], scale: [domain: domain])
      |> Vl.encode_field(:y, "value", type: :quantitative, title: nil, axis: nil, aggregate: "average"),
      Vl.new()
      |> Vl.mark(:line, opacity: 0.8, color: hd(assigns.theme.scale))
      |> Vl.encode_field(:x, "date", type: :temporal, title: nil, axis: nil, time_unit: [unit: time_unit], scale: [domain: domain])
      |> Vl.encode_field(:y, "value", type: :quantitative, title: nil, axis: nil, aggregate: "average"),
      Vl.new()
      |> Vl.transform(aggregate: [[op: "argmax", field: "date", as: "argmax_date"]])
      |> Vl.mark(:text, font_size: 50, font_weight: "bold", color: hd(assigns.theme.scale))
      |> Vl.encode(:text, type: :nominal, field: "argmax_date['value']", format: ".2f")
    ])
  end

  def build(%Telemetry.Metrics.Sum{}, data, assigns) do
    spec =
      assigns
      |> base_spec()
      |> Vl.data_from_url(data.source, name: "source")
      |> Vl.transform(aggregate: [[op: "sum", field: "value", as: "aggregate_value"]], groupby: ["tags"])
      |> Vl.encode_field(:x, "tags", type: :nominal, title: nil, axis: [label_angle: -30])
      |> Vl.encode_field(:color, "aggregate_value", title: nil, legend: nil)
      |> Vl.encode_field(:y, "aggregate_value", type: :quantitative, title: nil)

    Vl.layers(spec, [
      Vl.new()
      |> Vl.mark(:bar)
      |> Vl.encode(:tooltip, [[field: "aggregate_value", type: :quantitative, title: "Value", aggregate: "average", format: ".2f"]])
    ])
  end

  def build(%Telemetry.Metrics.Counter{}, data, assigns) do
    spec =
      assigns
      |> base_spec()
      |> Vl.data_from_url(data.source, name: "source")
      |> Vl.transform(aggregate: [[op: "sum", field: "count", as: "aggregate_count"]], groupby: ["tags"])
      |> Vl.encode_field(:x, "tags", type: :nominal, title: nil, axis: [label_angle: -30])
      |> Vl.encode_field(:color, "aggregate_count", title: nil, legend: nil)
      |> Vl.encode_field(:y, "aggregate_count", type: :quantitative, title: nil)

    Vl.layers(spec, [
      Vl.new()
      |> Vl.mark(:bar)
      |> Vl.encode(:tooltip, [[field: "aggregate_count", type: :quantitative, title: "Count", aggregate: "sum"]])
    ])
  end

  def build(%Telemetry.Metrics.LastValue{}, data, assigns) do
    spec =
      assigns
      |> base_spec()
      |> Vl.data_from_url(data.source, name: "source")
      |> Vl.transform(aggregate: [[op: "argmax", field: "date", as: "argmax_date"]], groupby: ["tags"])
      |> Vl.encode_field(:x, "tags", type: :nominal, title: nil, axis: [label_angle: -30])
      |> Vl.encode_field(:color, "argmax_date['value']", title: nil, legend: nil)
      |> Vl.encode_field(:y, "argmax_date['value']", type: :quantitative, title: nil)

    Vl.layers(spec, [
      Vl.new()
      |> Vl.mark(:bar)
      |> Vl.encode(:tooltip, [[field: "argmax_date['value']", type: :quantitative, title: "Value", aggregate: "sum"]])
    ])
  end

  def build(_, _, _), do: :not_supported

  defp fetch_time_unit(from, to) do
    case DateTime.diff(to, from) do
      diff when diff <= 43_200 -> "yearmonthdatehoursminutes"
      diff when diff <= 144_400 -> "yearmonthdatehours"
      _ -> "yearmonthdate"
    end
  end

  defp base_spec(assigns) do
    grid_color = "rgba(0,0,0,0.1)"
    label_color = "#666"

    Vl.config(
      Vl.new(width: "container", height: 100, background: "transparent"),
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
