defmodule TelemetryUI.InvalidMetricWebComponent do
  defexception [:message]

  @impl Exception
  def exception({metric}) do
    message = "Metric is not valid, it needs to implement the TelemetryUI.Web.Component protocol. Got: #{inspect(metric)}"

    %__MODULE__{message: message}
  end
end
