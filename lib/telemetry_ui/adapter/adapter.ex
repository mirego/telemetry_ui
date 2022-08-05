defmodule TelemetryUI.Adapter do
  @callback insert_event(float(), DateTime.t(), String.t(), map(), String.t(), non_neg_integer()) :: :ok
  @callback prune_events!(DateTime.t()) :: :ok
  @callback metric_tags(Telemetry.Metric.t()) :: [map()]
  @callback metric_data(Telemetry.Metric.t(), any(), map()) :: any()
end
