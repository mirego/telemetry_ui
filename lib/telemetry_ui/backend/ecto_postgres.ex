defmodule TelemetryUI.Backend.EctoPostgres do
  @moduledoc false
  import Ecto.Query

  @enforce_keys ~w(repo)a
  defstruct repo: nil,
            pruner_threshold: [months: -1],
            pruner_interval_ms: 84_000,
            max_buffer_size: 10_000,
            flush_interval_ms: 10_000,
            insert_date_bin: Duration.new!(minute: 5),
            verbose: false,
            telemetry_prefix: [:telemetry_ui, :repo],
            telemetry_options: [telemetry_ui_conf: []]

  defmodule Entry do
    @moduledoc false

    use Ecto.Schema

    @primary_key false
    schema "telemetry_ui_events" do
      field(:name, :string, load_in_query: false)
      field(:value, :float)
      field(:min_value, :float)
      field(:max_value, :float)
      field(:count, :integer)
      field(:date, :utc_datetime)
      field(:tags, :map)
    end
  end

  defimpl TelemetryUI.Backend do
    defmacro date_trunc(left, right) do
      quote do
        fragment("date_trunc(?::text, ?::timestamp)", unquote(left), unquote(right))
      end
    end

    def insert_event(backend, value, date, event_name, tags \\ %{}, count \\ 1) do
      backend.repo.query!(
        """
        INSERT INTO telemetry_ui_events (value, min_value, max_value, date, name, tags, count) VALUES($1, $1, $1, date_bin($6::interval, $2::timestamp, 'epoch'::timestamp), $3, $4, $5)
        ON CONFLICT (date, name, tags)
        DO UPDATE SET
          max_value = GREATEST(telemetry_ui_events.value, $1),
          min_value = LEAST(telemetry_ui_events.value, $1),
          value = ROUND((telemetry_ui_events.value + $1)::numeric / 2, 4),
          count = telemetry_ui_events.count + $5
        """,
        [value, date, event_name, tags, count, backend.insert_date_bin],
        log: backend.verbose,
        telemetry_prefix: backend.telemetry_prefix,
        telemetry_options: backend.telemetry_options
      )
    end

    def prune_events!(backend, date) do
      backend.repo.delete_all(
        from(entries in Entry, where: entries.date <= ^date),
        log: backend.verbose,
        telemetry_prefix: backend.telemetry_prefix,
        telemetry_options: backend.telemetry_options
      )
    end

    def metric_data(backend, metric, %TelemetryUI.Scraper.Options{} = options) do
      current =
        Entry
        |> aggregated_query(options)
        |> filter_tags(metric)
        |> select_buckets(metric)
        |> group_by_date(options)
        |> backend.repo.all()
        |> fill_buckets(metric)
        |> cast_date()

      compare =
        if Enum.any?(current) and options.compare do
          values =
            Entry
            |> compare_aggregated_query(options)
            |> filter_tags(metric)
            |> select_buckets(metric)
            |> group_by_date(options)
            |> backend.repo.all()
            |> cast_date()

          if Enum.empty?(values), do: [%{bucket_start: 0, bucket_end: 0, date: nil, compare: 1, count: 0, value: 0, min_value: 0.0, max_value: 0.0, tags: %{}}], else: values
        else
          []
        end

      Enum.concat(current, compare)
    end

    defp cast_date(records) do
      update_in(records, [Access.all(), :date], &DateTime.to_unix(DateTime.from_naive!(&1, "Etc/UTC"), :millisecond))
    end

    defp group_by_date(queryable, options) do
      interval = fetch_time_unit(options.from, options.to)

      from(
        entries in queryable,
        group_by: [fragment("group_date"), entries.tags],
        order_by: fragment("group_date ASC"),
        select_merge: %{
          date: fragment("? as group_date", date_trunc(^interval, entries.date))
        }
      )
    end

    defp compare_aggregated_query(queryable, options) do
      diff = DateTime.diff(options.from, options.to)
      from = DateTime.add(options.from, diff)
      to = DateTime.add(options.from, -1)

      from(
        entries in queryable,
        where:
          entries.name == ^options.event_name and
            entries.date >= ^from and
            entries.date <= ^to,
        select: %{
          compare: 1,
          value: fragment("avg(?)", entries.value),
          count: fragment("sum(?)", entries.count),
          tags: entries.tags
        }
      )
    end

    defp aggregated_query(queryable, options) do
      from(
        entries in queryable,
        where:
          entries.name == ^options.event_name and
            entries.date >= ^options.from and
            entries.date <= ^options.to,
        select: %{
          compare: 0,
          value: fragment("avg(?)", entries.value),
          count: fragment("sum(?)", entries.count),
          tags: entries.tags
        }
      )
    end

    def fetch_time_unit(from, to) do
      case DateTime.diff(to, from) do
        diff when diff <= 18_000 -> "second"
        diff when diff <= 43_200 -> "minute"
        diff when diff <= 691_200 -> "hour"
        _ -> "day"
      end
    end

    defp fill_buckets(events, metric) do
      if Keyword.has_key?(metric.reporter_options, :buckets) do
        all_buckets =
          metric
          |> fetch_buckets()
          |> then(&Enum.zip(&1, tl(&1) ++ [nil]))

        present_buckets =
          events
          |> Enum.uniq_by(&{&1.bucket_start, &1.bucket_end})
          |> Enum.map(&{&1.bucket_start, &1.bucket_end})

        to_fill_buckets = all_buckets -- present_buckets

        fill_events =
          Enum.map(to_fill_buckets, fn {bucket_start, bucket_end} ->
            %{
              min_value: 0.0,
              max_value: 0.0,
              value: 0.0,
              count: 0,
              compare: 0,
              date: DateTime.utc_now(),
              tags: %{},
              bucket_start: bucket_start,
              bucket_end: bucket_end
            }
          end)

        events ++ fill_events
      else
        events
      end
    end

    defp select_buckets(queryable, metric) do
      if Keyword.has_key?(metric.reporter_options, :buckets) do
        buckets = fetch_buckets(metric)

        from(entries in queryable,
          left_lateral_join: buckets in fragment("SELECT ?::double precision[] as values", ^buckets),
          on: true,
          select_merge: %{
            bucket_start:
              fragment(
                "min(?)",
                fragment(
                  "?[width_bucket(?::double precision,  ?)]",
                  buckets.values,
                  entries.value,
                  buckets.values
                )
              ),
            bucket_end:
              fragment(
                "min(?)",
                fragment(
                  "?[width_bucket(?::double precision,  ?) + 1]",
                  buckets.values,
                  entries.value,
                  buckets.values
                )
              )
          }
        )
      else
        queryable
      end
    end

    defp fetch_buckets(metric) do
      metric.reporter_options
      |> Keyword.fetch!(:buckets)
      |> Enum.map(&(&1 * 1.0))
    end

    defp filter_tags(queryable, metric) do
      if Enum.any?(metric.tags) do
        tags = Enum.map(metric.tags, &to_string/1)

        from(entries in queryable,
          where: fragment("ARRAY(SELECT jsonb_object_keys(?))", entries.tags) == ^tags
        )
      else
        from(entries in queryable, where: entries.tags == ^%{})
      end
    end
  end
end
