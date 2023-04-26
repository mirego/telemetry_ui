defmodule TelemetryUI.Web.Components.Buckets do
  @moduledoc false

  import TelemetryUI.Web.VegaLite.Spec

  alias VegaLite, as: Vl

  def spec(metric, assigns, options) do
    unit = to_unit(metric.unit)

    tooltip = [
      [field: "bucket_label", type: :ordinal, title: "Bucket"],
      [field: options.field, type: :quantitative, title: options.field_label, aggregate: options.summary_aggregate || options.aggregate, format: options.format]
    ]

    tooltip = if Enum.any?(metric.tags), do: tooltip ++ [[field: "tags", title: "Tags"]], else: tooltip

    spec =
      assigns
      |> base_spec()
      |> data_from_metric(metric, assigns)

    buckets_chart =
      Vl.new()
      |> Vl.transform(filter: "datum.compare==0")
      |> Vl.transform(calculate: "datum.bucket_start + '#{unit}' + (datum.bucket_end ? ' - ' + datum.bucket_end + '#{unit}' : ' +')", as: "bucket_label")
      |> encode_offset_tags_color(metric.tags, assigns)
      |> Vl.encode(:tooltip, tooltip)
      |> Vl.encode_field(:x, "bucket_label", type: :nominal, title: nil, axis: [label_angle: 0], sort: [field: "bucket_start"])
      |> Vl.encode_field(:y, options.field, aggregate: options.aggregate, type: :quantitative, title: nil, sort: [field: "bucket_start"])

    Vl.layers(spec, [title(metric), buckets_chart])
  end

  def encode_offset_tags_color(spec, tags, assigns) do
    bar_options = [
      align: "center",
      baseline: "line-bottom",
      tooltip: true,
      width: [band: 0.7],
      fill_opacity: 1,
      corner_radius_end: 2
    ]

    if Enum.any?(tags) do
      spec
      |> Vl.mark(:bar, bar_options)
      |> Vl.encode_field(:color, "tags", title: nil, legend: nil)
      |> Vl.encode_field(:x_offset, "tags")
      |> Vl.param("tags", select: [fields: ["tags"], type: :point], bind: "legend")
      |> Vl.encode(:opacity, value: 0.2, condition: [param: "tags", value: 1, empty: true])
    else
      Vl.mark(spec, :bar, bar_options ++ [color: hd(assigns.theme.scale)])
    end
  end
end
