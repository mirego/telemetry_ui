defmodule TelemetryUI.Web.Components.CompareAggregate do
  @moduledoc false

  alias VegaLite, as: Vl

  def fill_expression(metric) do
    {good, bad} = Keyword.get(metric.ui_options, :compare_value_scale, {"green", "red"})

    "datum.compare_percentage >= 50 ? '#{good}' : '#{bad}'"
  end

  def compare_icon_expression(_options) do
    "datum.compare_percentage >= 50 ? '▲ ' : '▼ '"
  end

  def spec(options) do
    Vl.new()
    |> Vl.transform(
      joinaggregate: [
        [op: options.aggregate, field: options.aggregate_field || options.field, as: "aggregate_value"]
      ],
      groupby: ["compare"]
    )
    |> Vl.transform(
      aggregate: [
        [op: "argmax", field: "compare", as: "compare_aggregate_value"],
        [op: "argmin", field: "compare", as: "current_aggregate_value"]
      ]
    )
    |> Vl.transform(
      calculate: "format(datum.current_aggregate_value['aggregate_value'], '#{options.format}')",
      as: "formatted_current_aggregate_value"
    )
    |> Vl.transform(
      calculate: "format(datum.compare_aggregate_value['aggregate_value'], '#{options.format}')",
      as: "formatted_compare_aggregate_value"
    )
    |> Vl.transform(
      calculate: "datum.compare_aggregate_value['aggregate_value'] > 0 ? datum.current_aggregate_value['aggregate_value']/datum.compare_aggregate_value['aggregate_value']*100 : 0",
      as: "compare_percentage"
    )
    |> Vl.transform(
      calculate: compare_icon_expression(options),
      as: "compare_percentage_icon"
    )
    |> Vl.transform(
      calculate: "datum.compare_percentage > 0 ? datum.compare_percentage_icon+format(datum.compare_percentage, '.2f')+'%' : ''",
      as: "formatted_compare_percentage"
    )
    |> Vl.encode(:text, type: :nominal, field: "formatted_compare_percentage")
    |> Vl.encode(:tooltip, [
      [field: "formatted_current_aggregate_value", title: "Current", type: :nominal],
      [field: "formatted_compare_aggregate_value", title: "Compare", type: :nominal]
    ])
  end
end
