defmodule TelemetryUI.Scraper do
  defmodule Options do
    defstruct from: nil, to: nil, step_interval: nil, step: nil, event_name: nil, query_aggregate: nil, query_field: nil
  end

  def metric(section, params, adapter) do
    duration = params[:frame_duration]
    {time_set, time_duration} = fetch_time_frame(params[:frame_unit], duration)

    to =
      DateTime.utc_now()
      |> DateTime.truncate(:second)
      |> Timex.shift(seconds: 1)

    from =
      to
      |> Timex.set(time_set)
      |> Timex.shift(time_duration)

    step =
      case DateTime.diff(to, from) do
        diff when diff <= 8600 -> "minute"
        diff when diff <= 432_000 -> "hour"
        diff when diff <= 2_592_000 -> "day"
        _ -> "month"
      end

    Enum.reduce(List.wrap(section.metric), [], fn definition, acc ->
      {metric, options} =
        case definition do
          {metric, options} -> {metric, options}
          {metric} -> {metric, %{}}
          %{} = metric -> {metric, %{}}
        end

      {query_aggregate, options} = Map.pop(options, :query_aggregate)
      {query_field, options} = Map.pop(options, :query_field)

      filter_options = %Options{
        from: from,
        to: to,
        step: step,
        step_interval: to_interval(step),
        event_name: TelemetryUI.Event.cast_event_name(metric),
        query_aggregate: query_aggregate || :average,
        query_field: query_field || :value
      }

      metric
      |> adapter.metric_tags()
      |> Enum.map(&{&1, adapter.metric_data(metric, &1, filter_options)})
      |> Enum.reduce(acc, fn
        {nil, data}, acc ->
          acc ++ [Map.merge(data, options)]

        {tag, data}, acc ->
          data = Map.merge(data, %{name: Enum.map_join(tag, ",", fn {key, value} -> "#{key}: #{value}" end)})
          acc ++ [Map.merge(data, options)]
      end)
    end)
  end

  defp to_interval("minute"), do: %Postgrex.Interval{secs: 60}
  defp to_interval("second"), do: %Postgrex.Interval{secs: 1}
  defp to_interval("hour"), do: %Postgrex.Interval{secs: 3600}
  defp to_interval("day"), do: %Postgrex.Interval{days: 1}
  defp to_interval("month"), do: %Postgrex.Interval{months: 1}

  defp fetch_time_frame("second", duration), do: {[second: 0], [seconds: -duration]}
  defp fetch_time_frame("minute", duration), do: {[second: 0], [minutes: -duration]}
  defp fetch_time_frame("hour", duration), do: {[second: 0, minute: 0], [hours: -duration]}
  defp fetch_time_frame("day", duration), do: {[second: 0, minute: 0, hour: 0], [days: -duration]}

  defp fetch_time_frame("week", duration),
    do: {[second: 0, minute: 0, hour: 0], [weeks: -duration]}

  defp fetch_time_frame(_, duration), do: fetch_time_frame("hour", duration)
end
