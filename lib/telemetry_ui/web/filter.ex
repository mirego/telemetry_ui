defmodule TelemetryUI.Web.Filter do
  @moduledoc false

  use Ecto.Schema

  @frame_options [
    {:last_30_minutes, 30, :minute},
    {:last_2_hours, 120, :minute},
    {:last_1_day, 1, :day},
    {:last_7_days, 7, :day},
    {:last_1_month, 1, :month},
    {:custom, 0, nil}
  ]

  @primary_key false
  embedded_schema do
    field(:page, :string)
    field(:from, :utc_datetime)
    field(:to, :utc_datetime)

    field(:frame, Ecto.Enum, values: Enum.map(@frame_options, &elem(&1, 0)), default: :last_30_minutes)
  end

  def frame_options(:custom), do: @frame_options
  def frame_options(_frame), do: Enum.reject(@frame_options, fn {option, _, _} -> option === :custom end)

  def cast(params = %{"frame" => "custom"}) do
    to =
      with to when not is_nil(to) <- params["to"],
           {:ok, datetime, _} <- DateTime.from_iso8601(to) do
        datetime
      else
        _ ->
          nil
      end

    from =
      with from when not is_nil(from) <- params["from"],
           {:ok, datetime, _} <- dbg(DateTime.from_iso8601(from)) do
        datetime
      else
        _ ->
          nil
      end

    %__MODULE__{from: from, to: to, frame: :custom, page: params["page"]}
  end

  def cast(params) do
    {option, duration, unit} = Enum.find(@frame_options, fn {name, _, _} -> to_string(name) === params["frame"] end) || Enum.at(@frame_options, 1)
    {time_set, time_duration} = fetch_time_frame(unit, duration)

    to =
      DateTime.utc_now()
      |> DateTime.truncate(:second)
      |> Timex.shift(seconds: 1)

    from =
      to
      |> Timex.set(time_set)
      |> Timex.shift(time_duration)

    %__MODULE__{from: from, to: to, frame: option, page: params["page"]}
  end

  defp fetch_time_frame(:second, duration), do: {[second: 0], [seconds: -duration]}
  defp fetch_time_frame(:minute, duration), do: {[second: 0], [minutes: -duration]}
  defp fetch_time_frame(:hour, duration), do: {[second: 0, minute: 0], [hours: -duration]}
  defp fetch_time_frame(:day, duration), do: {[second: 0, minute: 0], [days: -duration]}

  defp fetch_time_frame(:week, duration),
    do: {[second: 0, minute: 0, hour: 0], [weeks: -duration]}

  defp fetch_time_frame(:month, duration),
    do: {[second: 0, minute: 0, hour: 0], [months: -duration]}

  defp fetch_time_frame(_, duration), do: fetch_time_frame(:hour, duration)
end
