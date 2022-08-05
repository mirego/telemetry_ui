defmodule TelemetryUI.Adapter.EctoPostgres do
  @behaviour TelemetryUI.Adapter

  import Ecto.Query

  defmodule Entry do
    use Ecto.Schema

    @primary_key false
    schema "telemetry_ui_events" do
      field(:name, :string)
      field(:value, :float)
      field(:bucket, :string)
      field(:count, :integer)
      field(:date, :utc_datetime)
      field(:tags, :map)
    end
  end

  def insert_event(value, date, event_name, tags, bucket, count) do
    repo().query!(
      """
      INSERT INTO telemetry_ui_events (value, date, name, tags, bucket, count) VALUES($1, $2, $3, $4, $5, $6)
      ON CONFLICT (date, name, tags, bucket) DO UPDATE SET value = (telemetry_ui_events.value + $1) / 2, count = telemetry_ui_events.count + $6
      """,
      [value, date, event_name, tags, bucket, count]
    )
  end

  def prune_events!(date) do
    repo().delete_all(from(entries in Entry, where: entries.date <= ^date))
  end

  def metric_tags(%{tags: []}), do: [%{}]

  def metric_tags(metric) do
    name = TelemetryUI.Event.cast_event_name(metric)
    query = from(entries in Entry, select: entries.tags, distinct: true, where: [name: ^name])

    query
    |> repo().all()
    |> Enum.reject(&Enum.empty?/1)
    |> Enum.sort_by(&inspect(&1))
  end

  def metric_data(_metric = %Telemetry.Metrics.Sum{}, tag, options) do
    repo().one(
      from(
        entries in Entry,
        select: %{value: coalesce(sum(fragment("? * ?", entries.value, entries.count)), 0)},
        where: entries.date >= ^options.from and entries.date <= ^options.to,
        where: [name: ^options.event_name, tags: ^tag]
      )
    ) || %{value: 0}
  end

  def metric_data(_metric = %Telemetry.Metrics.LastValue{}, tag, options) do
    repo().one(
      from(
        entries in Entry,
        select: %{value: entries.value},
        where: [name: ^options.event_name, tags: ^tag],
        where: entries.date >= ^options.from and entries.date <= ^options.to,
        limit: 1,
        order_by: [desc: entries.date]
      )
    ) || %{value: 0}
  end

  def metric_data(_metric = %Telemetry.Metrics.Counter{}, tag, options) do
    repo().one(
      from(
        entries in Entry,
        select: %{value: coalesce(sum(entries.count), 0)},
        where: entries.date >= ^options.from and entries.date <= ^options.to,
        where: [name: ^options.event_name, tags: ^tag]
      )
    ) || %{value: 0}
  end

  def metric_data(metric = %Telemetry.Metrics.Distribution{}, tag, options) do
    data =
      from(
        entries in Entry,
        select: {entries.bucket, coalesce(sum(entries.count), 0)},
        where: entries.date >= ^options.from and entries.date <= ^options.to,
        where: [name: ^options.event_name, tags: ^tag],
        group_by: entries.bucket
      )
      |> repo().all()
      |> Enum.into(%{})

    %{
      x: metric.reporter_options[:buckets],
      y:
        Enum.map(metric.reporter_options[:buckets], fn bucket ->
          Map.get(data, to_string(bucket), 0)
        end)
    }
  end

  def metric_data(_metric = %Telemetry.Metrics.Summary{}, tag, options) do
    query = summary_query(options.query_aggregate, options)

    case repo().query!(
           query,
           [options.from, options.to, options.step_interval, options.step, options.event_name, tag]
         ).rows do
      [[value]] ->
        %{value: value}

      list ->
        {x, y} = Enum.unzip(Enum.map(list, &List.to_tuple/1))
        x = Enum.map(x, &DateTime.truncate(DateTime.from_naive!(&1, "Etc/UTC"), :second))
        %{x: x, y: y}
    end
  end

  defp summary_query({:list, :average}, options) do
    """
    SELECT series_steps, coalesce(avg(resolution.value)::float, 0) AS value
    #{summary_from(options)}
    GROUP BY series_steps ORDER BY series_steps ASC
    """
  end

  defp summary_query(:average, options) do
    """
    SELECT coalesce(avg(resolution.value)::float, 0) AS value
    #{summary_from(options)}
    """
  end

  defp summary_from(options) do
    """
    FROM generate_series($1::TIMESTAMP, $2::TIMESTAMP, $3::INTERVAL) AS series_steps
    LEFT JOIN (
        SELECT series, coalesce(avg(telemetry_ui_events.#{options.query_field})::float, 0) AS value
        FROM
            generate_series($1::TIMESTAMP, $2::TIMESTAMP, '1 minute'::INTERVAL) AS series
            LEFT JOIN telemetry_ui_events ON date_trunc('minute', telemetry_ui_events.date) = series AND telemetry_ui_events.name = $5 AND telemetry_ui_events.tags = $6
            GROUP BY series
    ) resolution ON date_trunc($4, resolution.series) = series_steps and resolution.value != 0
    """
  end

  defp repo do
    Application.get_env(:telemetry_ui, TelemetryUI.Adapter.EctoPostgres)[:repo]
  end
end
