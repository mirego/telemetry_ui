defmodule TelemetryUI.Web.VegaLite.Spec do
  @moduledoc false

  alias VegaLite, as: Vl

  defmodule Options do
    defstruct field: "value",
              field_label: "Value",
              aggregate: "average",
              summary_aggregate: nil,
              aggregate_field: nil,
              aggregate_label: "Average",
              format: ".2f",
              unit: "",
              aggregate_value_suffix: ""
  end

  def to_unit(:millisecond), do: "ms"
  def to_unit(:megabyte), do: "mb"
  def to_unit(unit), do: unit

  def fetch_time_unit(from, to) do
    case DateTime.diff(to, from) do
      diff when diff <= 43_200 -> "yearmonthdatehoursminutes"
      diff when diff <= 691_200 -> "yearmonthdatehours"
      _ -> "yearmonthdate"
    end
  end

  def base_spec(assigns, config \\ []) do
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

  def encode_tags_color(spec, metric) do
    if Enum.any?(metric.tags) do
      Vl.encode_field(spec, :color, "tags", title: nil, legend: nil)
    else
      spec
    end
  end

  def source(metric, assigns) do
    uri = URI.parse(assigns.conn.request_path <> "?" <> assigns.conn.query_string)

    source_query = Map.put(URI.decode_query(uri.query), "metric-data", metric.id)
    source_uri = %{uri | query: URI.encode_query(source_query)}

    URI.to_string(source_uri)
  end
end
