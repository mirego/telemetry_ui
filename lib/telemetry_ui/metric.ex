defmodule TelemetryUI.Metric do
  @moduledoc false

  def id(metric) do
    reporter_options = Enum.map_join(Enum.into(metric.reporter_options, %{}), "|", fn {key, value} -> "#{key}:#{value}" end)

    [
      metric.description,
      metric.name,
      metric.tags,
      reporter_options
    ]
    |> List.flatten()
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("-")
    |> Base.url_encode64(padding: false)
  end
end
