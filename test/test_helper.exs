defmodule TelemetryUI.Test.ErrorView do
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end

defmodule TelemetryUI.Test.Router do
  use Phoenix.Router

  defmodule Select do
    @moduledoc false
    import Plug.Conn

    def init(_), do: []

    def call(conn, _) do
      conn
      |> put_resp_header("content-type", "text/plain")
      |> send_resp(:ok, inspect(TelemetryUI.Test.Repo.query!("SELECT 1")))
    end
  end

  scope "/" do
    get("/", TelemetryUI.Test.Router.Select, [])

    get("/empty-metrics", TelemetryUI.Web, :index, assigns: %{telemetry_ui_name: :empty_metrics, telemetry_ui_allowed: true})
    get("/custom-render-metrics", TelemetryUI.Web, :index, assigns: %{telemetry_ui_name: :custom_render_metrics, telemetry_ui_allowed: true})
    get("/data-metrics", TelemetryUI.Web, :index, assigns: %{telemetry_ui_name: :data_metrics, telemetry_ui_allowed: true})
  end
end

defmodule TelemetryUI.Test.Endpoint do
  use Phoenix.Endpoint, otp_app: :telemetry_ui

  plug Plug.RequestId
  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug TelemetryUI.Test.Router
end

Application.ensure_all_started(:os_mon)

Mimic.copy(:httpc)

ExUnit.start(capture_log: true)

defmodule TestCustomRenderMetric do
  @moduledoc false
  use TelemetryUI.Metrics

  def new(attrs), do: struct!(__MODULE__, attrs)

  defimpl TelemetryUI.Web.Component do
    def to_image(_metric, _assigns) do
      "png"
    end

    def to_html(_metric, _assigns) do
      "Custom metric in render function"
    end
  end
end

custom_render_metric =
  TestCustomRenderMetric.new(%{
    id: "custom",
    title: "Custom",
    telemetry_metric: nil,
    data: nil,
    data_resolver: fn -> {:ok, []} end
  })

data_metric =
  TelemetryUI.Metrics.counter(:data,
    description: "Users count",
    unit: " users",
    data_resolver: fn ->
      {:ok, [%{compare: 0, date: DateTime.utc_now(), value: 1.2, count: 1}]}
    end
  )

Supervisor.start_link(
  [
    TelemetryUI.Test.Endpoint,
    TelemetryUI.Test.Repo,
    {TelemetryUI, [name: :digest_images, theme: [share_key: "012345678912345"], metrics: [{"Test", [data_metric]}]]},
    {TelemetryUI, [name: :digest, theme: [share_key: "012345678912345"], metrics: [{"Page", []}]]},
    {TelemetryUI, [name: :empty_metrics, metrics: [], theme: [title: "My test metrics"]]},
    {TelemetryUI, [name: :custom_render_metrics, metrics: [custom_render_metric], theme: [title: "My custom render metrics"]]},
    {TelemetryUI, [name: :data_metrics, metrics: [data_metric], theme: [title: "My data metrics"]]}
  ],
  strategy: :one_for_one
)

Ecto.Adapters.SQL.Sandbox.mode(TelemetryUI.Test.Repo, :manual)
