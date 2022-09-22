defmodule TelemetryUI.Backend.EctoPostgres do
  @enforce_keys ~w(repo)a
  defstruct repo: nil,
            pruner_threshold: [months: -1],
            pruner_interval: 84_000,
            max_buffer_size: 10_000,
            flush_interval_ms: 10_000,
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
        INSERT INTO telemetry_ui_events (value, date, name, tags, count, report_as) VALUES($1, date_trunc('minute'::text, $2::timestamp), $3, $4, $5, $6)
        ON CONFLICT (date, name, tags, report_as) DO UPDATE SET value = (telemetry_ui_events.value + $1) / 2, count = telemetry_ui_events.count + $5
        """,
        [value, date, event_name, tags, count, report_as],
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
      compare_unit = fetch_compare_unit(options.from, options.to)

      backend.repo.all(
        from(
          entries in Entry,
          where:
            entries.name == ^options.event_name and
              entries.date >= ^options.from and
              entries.date <= ^options.to,
          where: ^filter_tags(metric),
          where: ^filter_report_as(options.report_as),
          left_join: compare_entries in Entry,
          on:
            datetime_add(compare_entries.date, 1, ^compare_unit) == entries.date and
              compare_entries.name == entries.name and compare_entries.tags == entries.tags,
          select: %{
            compare_value: compare_entries.value,
            compare_date: compare_entries.date,
            compare_count: compare_entries.count,
            value: entries.value,
            count: entries.count,
            date: entries.date,
            tags: entries.tags
          }
        )
      )
    end

    defp fetch_compare_unit(from, to) do
      case DateTime.diff(to, from) do
        diff when diff <= 43_200 -> "hour"
        diff when diff <= 86_400 -> "day"
        _ -> "month"
      end
    end

    defp filter_report_as(nil), do: true

    defp filter_report_as(report_as) do
      dynamic([entries], entries.report_as == ^report_as)
    end

    defp filter_tags(metric) do
      if Enum.any?(metric.tags) do
        tags = Enum.map(metric.tags, &to_string/1)
        dynamic([entries], fragment("ARRAY(SELECT jsonb_object_keys(?))", entries.tags) == ^tags)
      else
        dynamic([entries], entries.tags == ^%{})
      end
    end
  end
end
