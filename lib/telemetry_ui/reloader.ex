defmodule TelemetryUI.Reloader do
  @moduledoc false
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, opts) do
    TelemetryUI.reload(opts)
    conn
  end
end
