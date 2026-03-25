defmodule TelemetryUI.InternalMetrics do
  @moduledoc """
  Provides built-in metrics about TelemetryUI's internal state.

  These metrics track:
  - Number of rows in the telemetry_ui_events table
  - Number of rows over time
  - Total count of events over time (to view pruning effects)
  """

  import Ecto.Query

  alias TelemetryUI.Metrics

  @table "telemetry_ui_events"

  @doc """
  Returns a list of internal metrics that should be appended to the user's metrics list.

  These metrics use custom data resolvers to query the backend directly.
  """
  def metrics(nil), do: []

  def metrics(backend) do
    [
      {"TelemetryUI Internal", Enum.map(metric_configs(), &build_metric(&1, backend)), ui_options: [hidden: true, metrics_class: "grid-cols-8 gap-4"]}
    ]
  end

  defp metric_configs do
    [
      %{
        type: &Metrics.counter_value/2,
        description: "Sum of events total",
        unit: " events",
        query_fn: &query_events_sum/2,
        time_range: false,
        ui_options: [class: "col-span-4"]
      },
      %{
        type: &Metrics.counter_value/2,
        description: "Count of rows total",
        unit: " rows",
        query_fn: &query_rows_count/2,
        time_range: false,
        ui_options: [class: "col-span-4"]
      },
      %{
        type: &Metrics.counter/2,
        description: "Sum of events in time range",
        unit: " events",
        query_fn: &query_events_sum/2,
        time_range: true,
        ui_options: [class: "col-span-4"]
      },
      %{
        type: &Metrics.counter/2,
        description: "Count of rows in time range",
        unit: " rows",
        query_fn: &query_rows_count/2,
        time_range: true,
        ui_options: [class: "col-span-4"]
      },
      %{
        type: &Metrics.counter/2,
        description: "Sum of events by name",
        unit: " events",
        tags: [:name],
        query_fn: &query_events_by_tag/2
      },
      %{
        type: &Metrics.count_list/2,
        description: "Entropy of tags",
        unit: " distinct tags",
        tags: [:name],
        query_fn: &query_tag_entropy/2
      }
    ]
  end

  defp build_metric(config, backend) do
    base_opts = [
      description: config.description,
      unit: config.unit,
      data_resolver: fn options -> execute_query(config, backend, options) end
    ]

    ui_opts = if config[:ui_options], do: [ui_options: config.ui_options], else: []
    tag_opts = if config[:tags], do: [tags: config.tags], else: []

    config.type.(:data, base_opts ++ ui_opts ++ tag_opts)
  end

  defp execute_query(config, backend, options) do
    query = config.query_fn.(options, config[:time_range])
    result = backend.repo.all(query) ++ [empty_compare_row()]
    {:ok, result}
  end

  def query_events_sum(options, true) do
    interval = fetch_time_unit(options.from, options.to)

    from e in @table,
      where: e.date >= ^options.from and e.date <= ^options.to,
      group_by: selected_as(:group_date),
      order_by: selected_as(:group_date),
      select: %{
        date: selected_as(fragment("date_trunc(?::text, ?::timestamp)", ^interval, e.date), :group_date),
        count: type(sum(e.count), :integer),
        compare: 0,
        value: 0,
        min_value: 0,
        max_value: 0,
        tags: type(^"", :string)
      }
  end

  def query_events_sum(_options, false) do
    from e in @table,
      select: %{
        date: type(^nil, :naive_datetime),
        count: type(sum(e.count), :integer),
        compare: 0,
        value: 0,
        min_value: 0,
        max_value: 0,
        tags: type(^"", :string)
      }
  end

  def query_events_sum(options, _), do: query_events_sum(options, false)

  def query_rows_count(options, true) do
    interval = fetch_time_unit(options.from, options.to)

    from e in @table,
      where: e.date >= ^options.from and e.date <= ^options.to,
      group_by: selected_as(:group_date),
      order_by: selected_as(:group_date),
      select: %{
        date: selected_as(fragment("date_trunc(?::text, ?::timestamp)", ^interval, e.date), :group_date),
        count: fragment("COUNT(*)::integer"),
        compare: 0,
        value: 0,
        min_value: 0,
        max_value: 0,
        tags: type(^"", :string)
      }
  end

  def query_rows_count(_options, false) do
    from e in @table,
      select: %{
        date: type(^nil, :naive_datetime),
        count: fragment("COUNT(*)::integer"),
        compare: 0,
        value: 0,
        min_value: 0,
        max_value: 0,
        tags: type(^"", :string)
      }
  end

  def query_rows_count(options, _), do: query_rows_count(options, false)

  def query_events_by_tag(options, _time_range) do
    interval = fetch_time_unit(options.from, options.to)

    from e in @table,
      where: e.date >= ^options.from and e.date <= ^options.to,
      group_by: [selected_as(:group_date), e.name],
      order_by: selected_as(:group_date),
      select: %{
        date: selected_as(fragment("date_trunc(?::text, ?::timestamp)", ^interval, e.date), :group_date),
        count: type(sum(e.count), :integer),
        compare: 0,
        value: 0,
        min_value: 0,
        max_value: 0,
        tags: e.name
      }
  end

  def query_tag_entropy(options, _time_range) do
    interval = fetch_time_unit(options.from, options.to)

    from e in @table,
      where: e.date >= ^options.from and e.date <= ^options.to,
      group_by: [selected_as(:group_date), e.name],
      order_by: selected_as(:group_date),
      select: %{
        date: selected_as(fragment("date_trunc(?::text, ?::timestamp)", ^interval, e.date), :group_date),
        count: fragment("COUNT(DISTINCT ?)::integer", e.tags),
        compare: 0,
        value: fragment("COUNT(DISTINCT ?)", e.tags),
        min_value: 0,
        max_value: 0,
        tags: e.name
      }
  end

  defp fetch_time_unit(from, to) do
    case DateTime.diff(to, from) do
      diff when diff <= 18_000 -> "second"
      diff when diff <= 43_200 -> "minute"
      diff when diff <= 691_200 -> "hour"
      _ -> "day"
    end
  end

  defp empty_compare_row do
    %{
      bucket_start: 0,
      bucket_end: 0,
      date: nil,
      compare: 1,
      count: 0,
      value: 0,
      min_value: 0.0,
      max_value: 0.0,
      tags: %{}
    }
  end
end
