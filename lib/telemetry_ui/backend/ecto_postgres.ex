defmodule TelemetryUI.Backend.EctoPostgres do
  @enforce_keys ~w(repo)a
  defstruct repo: nil,
            pruner_threshold: [months: -1],
            pruner_interval_ms: 84_000,
            max_buffer_size: 10_000,
            flush_interval_ms: 10_000,
            insert_date_trunc: "minute",
            verbose: false,
            telemetry_prefix: [:telemetry_ui, :repo]

  import Ecto.Query

  defmodule Entry do
    use Ecto.Schema

    @primary_key false
    schema "telemetry_ui_events" do
      field(:name, :string, load_in_query: false)
      field(:value, :float)
      field(:count, :integer)
      field(:date, :utc_datetime)
      field(:tags, :map)
      field(:report_as, :string, load_in_query: false)
    end
  end

  defimpl TelemetryUI.Backend do
    def insert_event(backend, value, date, event_name, tags \\ %{}, count \\ 1, report_as \\ "") do
      backend.repo.query!(
        """
        INSERT INTO telemetry_ui_events (value, date, name, tags, count, report_as) VALUES($1, date_trunc($7::text, $2::timestamp), $3, $4, $5, $6)
        ON CONFLICT (date, name, tags, report_as) DO UPDATE SET value = (telemetry_ui_events.value + $1) / 2, count = telemetry_ui_events.count + $5
        """,
        [value, date, event_name, tags, count, report_as, backend.insert_date_trunc],
        log: backend.verbose,
        telemetry_prefix: backend.telemetry_prefix
      )
    end

    def prune_events!(backend, date) do
      backend.repo.delete_all(
        from(entries in Entry, where: entries.date <= ^date),
        log: backend.verbose,
        telemetry_prefix: backend.telemetry_prefix
      )
    end

    def metric_data(backend, metric, options = %TelemetryUI.Scraper.Options{}) do
      query =
        from(
          entries in Entry,
          where:
            entries.name == ^options.event_name and
              entries.date >= ^options.from and
              entries.date <= ^options.to,
          order_by: [asc: :date],
          select: %{
            value: entries.value,
            count: entries.count,
            date: entries.date,
            tags: entries.tags
          }
        )

      query = select_compare_values(query, options)
      query = filter_tags(query, metric)
      query = filter_report_as(query, options.report_as)
      query = select_buckets(query, metric)

      backend.repo.all(query)
    end

    defp select_compare_values(queryable, options) do
      compare_unit =
        case DateTime.diff(options.to, options.from) do
          diff when diff <= 43_200 -> "hour"
          diff when diff <= 86_400 -> "day"
          _ -> "month"
        end

      from(entries in queryable,
        left_join: compare_entries in Entry,
        on:
          datetime_add(compare_entries.date, 1, ^compare_unit) == entries.date and
            compare_entries.name == entries.name and compare_entries.tags == entries.tags,
        select_merge: %{
          compare_date: compare_entries.date,
          compare_count: compare_entries.count,
          compare_value: compare_entries.value
        }
      )
    end

    defp select_buckets(queryable, metric) do
      if Keyword.has_key?(metric.reporter_options, :buckets) do
        buckets = Keyword.fetch!(metric.reporter_options, :buckets)

        from(query in queryable,
          left_lateral_join: buckets in fragment("SELECT ?::int[] as values", ^buckets),
          select_merge: %{
            bucket_start: fragment("?[width_bucket(?,  ?)]", buckets.values, query.value, buckets.values),
            bucket_end: fragment("?[width_bucket(?,  ?) + 1]", buckets.values, query.value, buckets.values)
          }
        )
      else
        queryable
      end
    end

    defp filter_report_as(queryable, nil), do: queryable

    defp filter_report_as(queryable, report_as) do
      from(entries in queryable, where: entries.report_as == ^report_as)
    end

    defp filter_tags(queryable, metric) do
      if Enum.any?(metric.tags) do
        tags = Enum.map(metric.tags, &to_string/1)
        from(entries in queryable, where: fragment("ARRAY(SELECT jsonb_object_keys(?))", entries.tags) == ^tags)
      else
        from(entries in queryable, where: entries.tags == ^%{})
      end
    end
  end
end
