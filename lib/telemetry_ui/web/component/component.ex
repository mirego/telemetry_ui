defmodule TelemetryUI.Web.Component do
  @callback draw(map()) :: any()
  @callback script() :: String.t()
  @callback style() :: String.t()

  defmacro __using__(_) do
    quote do
      use Phoenix.Component

      @behaviour TelemetryUI.Web.Component

      def script, do: file_content!("script.js")
      def style, do: file_content!("style.css")

      defp file_content!(name) do
        path = Path.join(Path.dirname(__ENV__.file), name)
        if File.exists?(path), do: File.read!(path), else: ""
      end

      defoverridable script: 0
    end
  end
end
