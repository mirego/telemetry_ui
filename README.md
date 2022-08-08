# Telemetry UI

- [Features](#features)
- [Usage](#usage)
  - [Installation](#installation)

## Features

TelemetryUI’s primary goal is to display your application metrics without external infrastructure dependencies.
Your data should not have to be uploaded somewhere else to have insighful metrics.

It comes with a Postgres adapter to quickly (and efficiently) store and query your application events.

## Usage

### Installation

TelemetryUI is published on Hex. Add it to your list of dependencies in `mix.exs`:

```elixir
# mix.exs
def deps do
  [
    {:telemetry_ui, ">= 0.0.1"}
  ]
end
```

Then run mix deps.get to install Telemetry and its dependencies.

After the packages are installed you must create a database migration to add the `telemetry_ui_events` table to your database:

```sh
mix ecto.gen.migration add_telemetry_ui_events_table
```

Open the generated migration in your editor and call the up and down functions on `TelemetryUI.Adapter.EctoPostres.Migrations`:

```elixir
defmodule MyApp.Repo.Migrations.AddTelemetryUIEventsTable do
  use Ecto.Migration

  def up do
    TelemetryUI.Adapter.EctoPostres.Migrations.up(version: 1)
  end

  # We specify `version: 1` in `down`, ensuring that we'll roll all the way back down if
  # necessary, regardless of which version we've migrated `up` to.
  def down do
    TelemetryUI.Adapter.EctoPostres.Migrations.down(version: 1)
  end
end
```

This will run all of TelemetryUI's versioned migrations for your database. Migrations between versions are idempotent and rarely change after a release. As new versions are released you may need to run additional migrations.

Now, run the migration to create the table:

```sh
mix ecto.migrate
```

Before you can run a TelemetryUI instance you must provide some configuration. Set some base configuration within config.exs:

```elixir
# config/config.exs
config :my_app, TelemetryUI.Adapter.EctoPostres, repo: MyApp.Repo
```

TelemetryUI instances are isolated supervision trees and must be included in your application's supervisor to run. Use the application configuration you've just set and include TelemetryUI in the list of supervised children:

```elixir
# lib/my_app/application.ex
def start(_type, _args) do
  children = [
    MyApp.Repo,
    {TelemetryUI, telemetry_config()}
  ]

  Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
end

defp telemetry_config do
  import Telemetry.Metrics

  [
    metrics: [
      counter("phoenix.router_dispatch.stop.duration", description: "Number of requests", unit: {:native, :millisecond}),
      summary("vm.memory.total", unit: {:byte, :megabyte}),
    ],
    adapter: TelemetryUI.Adapter.EctoPostgres,
    pruner: [threshold: [months: -1], interval: 84_000],
    write_buffer: [max_buffer_size: 10_000, flush_interval_ms: 5_000]
  ]
end
```

Since the config is read once at startup, you need to restart the server of you add new metrics to track.

To see the rendered metrics, you need to add a route to your router.

```elixir
# lib/my_app_web/router.ex
get("/metrics", TelemetryUI.Web, [])
```

#### Security

But since it may contain sensitive data, TelemetryUI require a special assign to render the page.

`:telemetry_ui_allowed` must be set to true in the `conn` struct before it enters the `TelemetryUI.Web` module.
The easiest way to do that in a Phoenix router is to use a pipeline with a private function

```elixir
pipeline :telemetry_ui do
  plug(:allow)
end

scope "/" do
  pipe_through(:telemetry_ui)
  get("/metrics", TelemetryUI.Web, [])
end

defp allow(conn, _), do: assign(conn, :telemetry_ui_allowed, true)
```

By using a special assign to control access, you can integrate `TelemetryUI` page with you existing authorization. We can imagine an admin protected section that also gives you access to the `TelemetryUI` page:

```elixir
pipeline :admin_protected do
  plug(MyAppWeb.EnsureCurrentUser)
  plug(MyAppWeb.EnsureRole, :admin)
  plug(:enable_telemetry_ui)
end

def enable_telemetry_ui(conn, _), do: assign(conn, :telemetry_ui_allowed, true)
```

That’s it! You can declare as many metrics as you want and they will render in HTML on your page!
