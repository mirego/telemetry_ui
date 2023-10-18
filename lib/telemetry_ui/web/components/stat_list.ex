defmodule TelemetryUI.Web.Components.StatList do
  @moduledoc false

  import TelemetryUI.Web.VegaLite.Spec

  alias VegaLite, as: Vl

  def spec(%{tags: []} = metric, assigns, options) do
    TelemetryUI.Web.Components.Stat.spec(metric, assigns, options)
  end

  def spec(metric, assigns, options) do
    chart_offset = 80

    assigns
    |> base_spec(height: [step: 20])
    |> data_from_metric(metric, assigns)
    |> Vl.param("date_domain", value: [])
    |> Vl.layers([
      title(metric, y: -20),
      Vl.new()
      |> Vl.transform(filter: "datum.compare==0")
      |> Vl.transform(
        aggregate: [[op: options.aggregate, field: options.field, as: "aggregate_value"]],
        groupby: ["tags"]
      )
      |> Vl.encode_field(:y, "tags",
        sort: "-x",
        type: :nominal,
        title: nil,
        axis: [label_angle: 0, label_limit: 500]
      )
      |> Vl.encode_field(:color, "tags", title: nil, legend: nil)
      |> Vl.encode_field(:x, "aggregate_value#{options.aggregate_value_suffix}",
        type: :quantitative,
        title: nil
      )
      |> Vl.mark(:bar,
        height: [band: 0.3],
        corner_radius_end: 2,
        y: chart_offset
      )
      |> Vl.encode(:tooltip, [
        [
          field: "aggregate_value#{options.aggregate_value_suffix}",
          type: :quantitative,
          title: options.field_label,
          aggregate: options.aggregate,
          format: options.format
        ]
      ]),
      Vl.new()
      |> Vl.transform(filter: "datum.compare==0")
      |> Vl.transform(
        aggregate: [[op: options.aggregate, field: options.field, as: "aggregate_value"]],
        groupby: ["tags"]
      )
      |> Vl.encode_field(:text, "aggregate_value#{options.aggregate_value_suffix}",
        format: options.format,
        type: :quantitative,
        title: nil
      )
      |> Vl.encode_field(:y, "tags",
        sort: "-x",
        type: :nominal,
        title: nil,
        axis: [label_angle: 0, label_limit: 500]
      )
      |> Vl.encode_field(:color, "tags", title: nil, legend: nil)
      |> Vl.encode_field(:x, "aggregate_value#{options.aggregate_value_suffix}",
        type: :quantitative,
        title: nil
      )
      |> Vl.mark(:text,
        x_offset: 4,
        y: chart_offset,
        font_weight: "bold",
        font_size: 13,
        align: "left"
      )
    ])
  end
end
