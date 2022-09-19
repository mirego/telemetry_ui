defmodule TelemetryUI.Scraper do
  @moduledoc false

  import TelemetryUI.Event

  defmodule Options do
    defstruct from: nil, to: nil, event_name: nil, report_as: nil

    @type t :: %__MODULE__{}
  end

  def metric(backend, metric, params) do
    filters = filter_options(params)

    filters = %{
      filters
      | report_as: cast_report_as(metric),
        event_name: cast_event_name(metric)
    }

    backend
    |> TelemetryUI.Backend.metric_data(metric, filters)
    |> Enum.map(&map_tags/1)
  end

  defp map_tags(entry) when map_size(entry.tags) === 0 or is_nil(entry.tags) do
    %{entry | tags: nil}
  end

  defp map_tags(entry) do
    update_in(entry, [:tags], fn tags ->
      if map_size(tags) === 1 do
        Enum.map_join(tags, ",", fn {_key, value} -> "#{value}" end)
      else
        Enum.map_join(tags, ",", fn {key, value} -> "#{key}: #{value}" end)
      end
    end)
  end

  def filter_options(params) do
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

    %Options{from: from, to: to}
  end

  defp fetch_time_frame("second", duration), do: {[second: 0], [seconds: -duration]}
  defp fetch_time_frame("minute", duration), do: {[second: 0], [minutes: -duration]}
  defp fetch_time_frame("hour", duration), do: {[second: 0, minute: 0], [hours: -duration]}
  defp fetch_time_frame("day", duration), do: {[second: 0, minute: 0, hour: 0], [days: -duration]}

  defp fetch_time_frame("week", duration),
    do: {[second: 0, minute: 0, hour: 0], [weeks: -duration]}

  defp fetch_time_frame(_, duration), do: fetch_time_frame("hour", duration)
end
