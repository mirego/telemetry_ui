defmodule TelemetryUI.InvalidMetricWebComponent do
  defexception [:message]

  @impl Exception
  def exception({metric}) do
    message = "Metric :web_component value is not valid, it needs to implement the TelemetryUI.Web.Component protocol. Got: #{inspect(metric.web_component)}"

    %__MODULE__{message: message}
  end
end

defmodule TelemetryUI.InvalidMetric do
  defexception [:message]

  @impl Exception
  def exception({metric}) do
    message =
      "Metric is not valid, ensure you have a struct with a :web_component key. See TelemetryUI.Metrics.Summary for an example. Expected valid metric struct, got: #{inspect(metric)}"

    %__MODULE__{message: message}
  end
end
