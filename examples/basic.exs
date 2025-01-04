#!/usr/bin/env elixir
Mix.install([
  {:phoenix_playground, "~> 0.1"},
  {:telemetry_ui, path: "../telemetry_ui/"},
  {:telemetry_poller, "~> 1.0"},
  {:ecto, "~> 3.0"},
  {:ecto_sql, "~> 3.0"},
  {:postgrex, "~> 0.1"},
  {:vix, "~> 0.30"},
  {:vega_lite_convert, "~> 1.0"},
])

defmodule CounterLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket, count: 0)}
  end

  def render(assigns) do
    ~H"""
    <span><%= @count %></span>
    <button phx-click="inc">+</button>
    <button phx-click="dec">-</button>

    <style type="text/css">
      body { padding: 1em; }
    </style>
    """
  end

  def handle_event("inc", _params, socket) do
    {:noreply, assign(socket, count: socket.assigns.count + 1)}
  end

  def handle_event("dec", _params, socket) do
    {:noreply, assign(socket, count: socket.assigns.count - 1)}
  end
end

defmodule DemoRouter do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :put_root_layout, html: {PhoenixPlayground.Layout, :root}
    plug :put_secure_browser_headers
  end

  scope "/" do
    pipe_through :browser

    live "/", CounterLive
  end

  scope "/" do
    get("/metrics", TelemetryUI.Web, [], [assigns: %{telemetry_ui_allowed: true}])
  end
end

defmodule Repo do
  use Ecto.Repo, otp_app: :phoenix_playground, adapter: Ecto.Adapters.Postgres
end

defmodule TelemetryUIConfig do
  def config do
    import TelemetryUI.Metrics
    http_keep = &(not String.starts_with?(&1[:route], "/metrics"))

    [
      metrics: [
        # counter("phoenix.router_dispatch.stop.duration", keep: http_keep, description: "Number of requests", unit: {:native, :millisecond}, ui_options: [unit: " requests"]),
        # count_over_time("phoenix.live_view.handle_event.stop.duration", description: "LiveView events", tags: [:event], unit: {:native, :millisecond}),
        # value_over_time("vm.memory.total", unit: {:byte, :megabyte}),
        counter(:data,
          description: "Events count",
          unit: " events",
          data_resolver: fn options ->
            import Ecto.Query

            query =
              from(
                events in "telemetry_ui_events",
                select: %{date: events.date, count: events.count},
                where: events.date >= ^options.from and events.date <= ^options.to
              )

            {:ok, Repo.all(query)}
        end)
      ],
      backend: %TelemetryUI.Backend.EctoPostgres{
        repo: Repo,
        flush_interval_ms: 1_000,
        insert_date_bin: Duration.new!(minute: 1),
        verbose: true
      }
    ]
  end
end

Application.put_env(:phoenix_playground, Repo,
  database: "telemetry_ui_examples_basic",
  username: "postgres",
  password: "development",
  hostname: "localhost",
  migration_lock: :pg_advisory_lock,
  port: 5436
)

{:ok, _} = Application.ensure_all_started(:postgrex)
{:ok, _} = Application.ensure_all_started(:ecto)

defmodule Migrator do
  def up do
    migrations = [
      {0, TelemetryUI.Backend.EctoPostgres.Migrations.V01},
      {1, TelemetryUI.Backend.EctoPostgres.Migrations.V02},
      {2, TelemetryUI.Backend.EctoPostgres.Migrations.V03},
    ]
    Ecto.Migrator.run(Repo, migrations, :up, all: true)
  end
end

PhoenixPlayground.start(plug: DemoRouter, open_browser: false, live_reload: nil, child_specs: [
  {Repo, []},
  {TelemetryUI, TelemetryUIConfig.config()}
])

Migrator.up()
