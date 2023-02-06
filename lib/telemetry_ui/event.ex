defmodule TelemetryUI.Event do
  @moduledoc false

  @enforce_keys ~w(value time event_name tags)a
  defstruct value: 0, time: nil, event_name: nil, tags: %{}, cast_value: nil

  def cast_event_name(metric) do
    Enum.join(metric.name, ".")
  end

  def cast_reporter_cast_value(metric) do
    Keyword.get(metric.reporter_options, :cast_value)
  end
end
