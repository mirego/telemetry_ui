defmodule TelemetryUI.Web.Filter do
  @moduledoc false

  use Ecto.Schema

  @frame_options [
    {:last_10_minutes, frame_unit: "minute", frame_duration: 10},
    {:last_30_minutes, frame_unit: "minute", frame_duration: 30},
    {:last_1_hour, frame_unit: "minute", frame_duration: 60},
    {:last_2_hours, frame_unit: "minute", frame_duration: 120},
    {:last_12_hours, frame_unit: "hour", frame_duration: 12},
    {:last_1_day, frame_unit: "day", frame_duration: 1},
    {:last_7_days, frame_unit: "day", frame_duration: 7}
  ]

  @primary_key false
  embedded_schema do
    field(:frame_duration, :integer, default: 30)
    field(:frame_unit, :string, default: "minute")
    field(:frame, Ecto.Enum, values: Enum.map(@frame_options, &elem(&1, 0)), default: :last_30_minutes)
  end

  def frame_options, do: @frame_options

  for {frame_option, attributes} <- @frame_options do
    def cast_frame_options(filter = %{frame: unquote(frame_option)}), do: Map.merge(filter, Enum.into(unquote(attributes), %{}))
  end

  def cast_frame_options(filter), do: filter
end
