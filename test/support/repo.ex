defmodule TelemetryUI.Test.Repo do
  use Ecto.Repo,
    adapter: Ecto.Adapters.Postgres,
    otp_app: :telemetry_ui

  def init(_, opts) do
    {:ok, Keyword.put(opts, :url, Application.get_env(:telemetry_ui, __MODULE__)[:url])}
  end
end
