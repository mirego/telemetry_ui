defmodule TelemetryUI.NotStartedError do
  defexception [:message]

  @impl Exception
  def exception(_) do
    message = "TelemetryUI needs to be started in your application

    # lib/my_app/application.ex
    def start(_type, _args) do
      children = [
        MyApp.Repo,
        {TelemetryUI, [metrics: []]}
      ]

      #...
    end
    "

    %__MODULE__{message: message}
  end
end

defmodule TelemetryUI.InvalidMetricWebComponentError do
  defexception [:message]

  @impl Exception
  def exception({metric}) do
    message = "Metric is not valid, it needs to implement the TelemetryUI.Web.Component protocol. Got: #{inspect(metric)}"

    %__MODULE__{message: message}
  end
end

defmodule TelemetryUI.InvalidThemeShareKeyError do
  defexception [:message]

  @impl Exception
  def exception(key) do
    message = ":share_key is not valid. It must be a a binary of exactly 16 characters. Got: #{inspect(key)} (#{String.length(key)} characters)"

    %__MODULE__{message: message}
  end
end
