defmodule TelemetryUI.Web.VegaLite.Spec do
  @moduledoc false

  alias VegaLite, as: Vl

  defmodule Options do
    @moduledoc false

    defstruct field: "value",
              field_label: "Value",
              aggregate: "average",
              summary_aggregate: nil,
              aggregate_field: nil,
              aggregate_label: "Average",
              format: "~s",
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

  def title(metric, mark_options \\ []) do
    options = Keyword.merge([font_size: 16, description: "main-title", color: "#333", x: 0, y: 0, align: "left"], mark_options)

    Vl.new()
    |> Vl.transform(aggregate: [[op: "min", field: "date", as: "single_value"]])
    |> Vl.mark(:text, options)
    |> Vl.encode(:text, value: metric.title)
  end

  def base_spec(assigns, extra_options \\ []) do
    options = base_options(assigns)

    Vl.config(Vl.new(assigns.default_config), options ++ extra_options)
  end

  defp base_options(assigns) do
    grid_color = "rgba(0,0,0,0.1)"
    label_color = "#666"

    [
      autosize: [type: "fit-x"],
      axis_y: [domain_color: label_color, label_color: label_color, tick_color: label_color, grid_color: grid_color],
      axis_x: [domain_color: label_color, label_color: label_color, tick_color: label_color, grid_color: grid_color],
      view: [stroke: nil],
      range: [category: assigns.theme.scale]
    ]
  end

  def encode_tags_color(spec, nil), do: spec
  def encode_tags_color(spec, []), do: spec

  def encode_tags_color(spec, _tags) do
    Vl.encode_field(spec, :color, "tags", title: nil, legend: nil)
  end

  def data_from_metric(spec, metric, assigns) do
    if metric.data do
      Vl.data_from_values(spec, metric.data, name: :source)
    else
      uri = URI.parse(assigns.conn.request_path <> "?" <> assigns.conn.query_string)

      source_query = Map.put(URI.decode_query(uri.query), "metric-data", metric.id)
      source_uri = %{uri | query: URI.encode_query(source_query)}

      Vl.data_from_url(spec, URI.to_string(source_uri), name: :source)
    end
  end
end
