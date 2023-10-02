defmodule TelemetryUI.Web.Component.Assigns do
  @moduledoc false

  defstruct theme: nil, conn: nil, filters: nil, options: %{}, default_config: [width: "container", height: 100, background: "transparent"]
end
