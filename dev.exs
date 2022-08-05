Application.put_env(:phoenix, :logger, true)
Application.put_env(:phoenix, :json_library, Jason)
Application.put_env(:logger, :console, format: "[$metadata] [$level] $message\n", metadata: ~w(mfa current_user_id)a)
Application.put_env(:logger, :backends, [:console])
Application.put_env(:telemetry_ui, TelemetryUI.Adapter.EctoPostgres, repo: Demo.Repo)

Application.put_env(:sample, Demo.Repo, url: System.get_env("DATABASE_URL"))

Application.put_env(:sample, DemoWeb.Endpoint,
  server: true,
  secret_key_base: String.duplicate("a", 64),
  http: [ip: {127, 0, 0, 1}, port: System.get_env("PORT")]
)

Application.ensure_all_started(:os_mon)

Mix.install([
  {:telemetry_ui, path: "./"},
  {:plug_cowboy, "~> 2.5"},
  {:jason, "~> 1.0"},
  {:telemetry_metrics, "~> 0.6"},
  {:phoenix, "~> 1.6"},
  {:ecto, "~> 3.8"},
  {:ecto_sql, "~> 3.8"}
])

defmodule DemoWeb.GraphQLController do
  use Phoenix.Controller

  def index(conn, _) do
    status = Enum.random([200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 400, 403, 500])
    sleep = Enum.random(1..500)
    Process.sleep(sleep)

    conn
    |> put_status(status)
    |> text("Took #{sleep}ms")
    |> halt()
  end
end

defmodule DemoWeb.Router do
  use Phoenix.Router
  use Plug.ErrorHandler

  pipeline :telemetry_ui do
    plug(:allow_metrix)
  end

  get("/graphql", DemoWeb.GraphQLController, :index)

  scope "/" do
    pipe_through :telemetry_ui
    get("/metrics", TelemetryUI.Web, [])
  end

  defp allow_metrix(conn, _), do: assign(conn, :telemetry_ui_allowed, true)
end

defmodule DemoWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :sample

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  plug(DemoWeb.Router)
end

defmodule Demo.Repo do
  use Ecto.Repo, otp_app: :sample, adapter: Ecto.Adapters.Postgres
end

_ = Ecto.Adapters.Postgres.storage_up(Demo.Repo.config())

defmodule TelemetryUIConfig do
  import Telemetry.Metrics

  def all do
    keep = &(&1[:route] !== "/metrics")

    metrics = [
      counter("phoenix.router_dispatch.stop.duration", description: "Number of requests", unit: {:native, :millisecond}, keep: keep),
      last_value("phoenix.router_dispatch.stop.duration", description: "Last GraphQL request duration", unit: {:native, :millisecond}, keep: keep),
      summary("phoenix.router_dispatch.stop.duration", description: "Average GraphQL request duration", unit: {:native, :millisecond}, keep: keep),
      distribution(
        "phoenix.router_dispatch.stop.duration",
        unit: {:native, :millisecond},
        tags: [:status],
        tag_values: & &1[:conn],
        keep: keep,
        reporter_options: [buckets: [0, 10, 50, 90, 120, 500]]
      ),
      # Phoenix Metrics
      summary("phoenix.endpoint.stop.duration",
        keep: keep,
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        keep: keep,
        unit: {:native, :millisecond}
      ),
      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :megabyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]

    [
      metrics: metrics,
      theme: %{header_color: "#666", title: "Telemetry UI"},
      adapter: TelemetryUI.Adapter.EctoPostgres,
      pruner: [threshold: [months: -1], interval: 84_000],
      write_buffer: [max_buffer_size: 10_000, flush_interval_ms: 5_000]
    ]
  end
end

children = [
  Demo.Repo,
  DemoWeb.Endpoint,
  {TelemetryUI, TelemetryUIConfig.all()}
]

defmodule Demo.Migration do
  use Ecto.Migration

  def up do
    TelemetryUI.Adapter.EctoPostres.Migrations.up()
  end

  def down do
    TelemetryUI.Adapter.EctoPostres.Migrations.down()
  end
end

{:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
Ecto.Migrator.up(Demo.Repo, String.to_integer(Calendar.strftime(DateTime.utc_now(), "%Y%m%d%H%M0000")), Demo.Migration)

Process.sleep(:infinity)
