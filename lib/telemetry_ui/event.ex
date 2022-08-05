defmodule TelemetryUI.Event do
  @enforce_keys ~w(value time bucket event_name tags)a
  defstruct value: 0, time: nil, event_name: nil, tags: %{}, bucket: nil

  def cast_event_name(metric) do
    maybe_suffix(metric, Enum.join(metric.name, "."))
  end

  defp maybe_suffix(%Telemetry.Metrics.Distribution{}, name), do: name <> ".distribution"
  defp maybe_suffix(_, name), do: name
end
