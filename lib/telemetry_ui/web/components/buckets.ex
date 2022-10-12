defmodule TelemetryUI.Web.Components.Buckets do
  import TelemetryUI.Web.VegaLite.Spec

  alias VegaLite, as: Vl

  def render(metric, assigns, options) do
    source = source(metric, assigns)
    unit = to_unit(metric.unit)

    tooltip = [
      [field: "bucket_label", type: :ordinal, title: "Bucket"],
      [field: options.field, type: :quantitative, title: options.field_label, aggregate: options.summary_aggregate || options.aggregate, format: options.format]
    ]

    tooltip = if Enum.any?(metric.telemetry_metric.tags), do: tooltip ++ [[field: "tags", title: "Tags"]], else: tooltip

    assigns
    |> base_spec()
    |> Vl.data_from_url(source, name: "source")
    |> Vl.transform(calculate: "datum.bucket_start + '#{unit}' + (datum.bucket_end ? ' - ' + datum.bucket_end + '#{unit}' : ' +')", as: "bucket_label")
    |> encode_offset_tags_color(metric.telemetry_metric, assigns)
    |> Vl.encode(:tooltip, tooltip)
    |> Vl.encode_field(:x, "bucket_label", type: :nominal, title: nil, axis: [label_angle: 0], sort: [field: "bucket_start"])
    |> Vl.encode_field(:y, options.field, aggregate: options.aggregate, type: :quantitative, title: nil, sort: [field: "bucket_start"])
    |> TelemetryUI.Web.VegaLite.draw(metric)
  end

  def encode_offset_tags_color(spec, metric, assigns) do
    bar_options = [
      align: "center",
      baseline: "line-bottom",
      tooltip: true,
      width: [band: 0.7],
      fill_opacity: 1,
      corner_radius_end: 2
    ]

    if Enum.any?(metric.tags) do
      spec
      |> Vl.mark(:bar, bar_options)
      |> Vl.encode_field(:color, "tags", title: nil, legend: nil)
      |> Vl.encode_field(:x_offset, "tags")
    else
      Vl.mark(spec, :bar, bar_options ++ [color: hd(assigns.theme.scale)])
    end
  end
end
