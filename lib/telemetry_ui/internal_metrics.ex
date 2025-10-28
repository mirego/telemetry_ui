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
      },
      %{
        type: &Metrics.counter/2,
        description: "Sum of events total",
        unit: " events",
        query_fn: &query_events_sum/2,
        time_range: false,
        ui_options: [class: "col-span-4"]
      },
      %{
        type: &Metrics.counter/2,
        description: "Count of rows total",
        unit: " rows",
        query_fn: &query_rows_count/2,
        time_range: false,
        ui_options: [class: "col-span-4"]
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
    from e in base_query(),
      where: e.date >= ^options.from and e.date <= ^options.to
  end

  def query_events_sum(_options, false) do
    base_query()
  end

  def query_rows_count(options, true) do
    from e in base_query(),
      where: e.date >= ^options.from and e.date <= ^options.to,
      select_merge: %{count: 1}
  end

  def query_rows_count(_options, false) do
    from e in base_query(), select_merge: %{count: 1}
  end

  def query_events_by_tag(options, _time_range) do
    from e in base_query(),
      where: e.date >= ^options.from and e.date <= ^options.to,
      select_merge: %{tags: e.name}
  end

  def query_tag_entropy(options, _time_range) do
    from e in @table,
      where: e.date >= ^options.from and e.date <= ^options.to,
      group_by: e.name,
      select: %{
        date: nil,
        count: fragment("COUNT(DISTINCT ?)", e.tags),
        compare: 0,
        value: fragment("COUNT(DISTINCT ?)", e.tags),
        min_value: 0,
        max_value: 0,
        tags: e.name
      }
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

  defp base_query do
    from e in @table,
      select: %{
        date: e.date,
        count: e.count,
        compare: 0,
        value: 0,
        min_value: 0,
        max_value: 0,
        tags: %{}
      }
  end
end
