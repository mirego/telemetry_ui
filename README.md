<div align="center">
  <img src="https://user-images.githubusercontent.com/464900/183483800-f313a3c0-1877-4c37-ac07-e08bed3f2276.png" width="500" />
  <br /><br />
  Telemetry-based metrics UI. Take your <a href="https://github.com/beam-telemetry/telemetry"><code>telemetry</code></a> metrics and display them in a web page.
  <br /><br />
  <a href="https://hex.pm/packages/telemetry_ui"><img src="https://img.shields.io/hexpm/v/telemetry_ui.svg" /></a>
</div>

## Features

`TelemetryUI`’s primary goal is to display [your application metrics](https://hexdocs.pm/telemetry_metrics) without external infrastructure dependencies. [Plug](https://hexdocs.pm/plug/Plug.Telemetry.html), [Phoenix](https://hexdocs.pm/phoenix/telemetry.html), [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/telemetry.html), [Absinthe](https://hexdocs.pm/absinthe/telemetry.html), [Ecto](https://hexdocs.pm/ecto/Ecto.Repo.html#module-telemetry-events), [Erlang VM](https://hexdocs.pm/telemetry_poller/readme.html), [Tesla](https://hexdocs.pm/tesla/Tesla.Middleware.Telemetry.html), [Finch](https://hexdocs.pm/finch/Finch.Telemetry.html), [Redix](https://hexdocs.pm/redix/telemetry.html), [Oban](https://hexdocs.pm/oban/Oban.Telemetry.html), [Broadway](https://hexdocs.pm/broadway/Broadway.html#module-telemetry) and others expose all sorts of data that can be useful. You can also emit your own events from your application.

Your data should not have to be uploaded somewhere else to have insighful metrics.

It comes with a Postgres backend, powered by [Ecto](https://hexdocs.pm/ecto), to quickly (and efficiently) store and query your application events.

<img alt="Screenshot of /metrics showcasing values and charts" src="https://github.com/mirego/telemetry_ui/assets/464900/88a9863f-4762-42cd-90cb-74a433ec1494">

### Advantages over other tools

- Persisted metrics inside your own database
- Live dashboard
- Many built-in charts and visualizations using [VegaLite](https://vega.github.io/vega-lite/)

### Advanced features

- 100% custom UI hook to show your own components
- 100% custom data fetching to show live data
- Shareable metrics page (secured, cacheable, without external requests)
- Slack digest with rendered images
- Multiple metrics dashboard living in the same app

Checkout the Guides for more informations.

## Usage

### Installation

TelemetryUI is published on Hex. Add it to your list of dependencies in `mix.exs`:

```elixir
# mix.exs
def deps do
  [
    {:telemetry_ui, "~> 4.0"}
  ]
end
```

Configure TelemetryUI for test.

```elixir
# config/test.exs
config :telemetry_ui, disabled: true
```

Then run mix deps.get to install Telemetry and its dependencies.

After the packages are installed you must create a database migration to add the `telemetry_ui_events` table to your database:

```sh
mix ecto.gen.migration add_telemetry_ui_events_table
```

Open the generated migration in your editor and call the up and down functions on `TelemetryUI.Adapter.EctoPostgres.Migrations`:

```elixir
defmodule MyApp.Repo.Migrations.AddTelemetryUIEventsTable do
  use Ecto.Migration

  @disable_migration_lock true
  @disable_ddl_transaction true

  def up do
    TelemetryUI.Backend.EctoPostgres.Migrations.up()
  end

  # We specify `version: 1` in `down`, ensuring that we'll roll all the way back down if
  # necessary, regardless of which version we've migrated `up` to.
  def down do
    TelemetryUI.Backend.EctoPostgres.Migrations.down(version: 1)
  end
end
```

This will run all of TelemetryUI's versioned migrations for your database. Migrations between versions are idempotent and rarely change after a release. As new versions are released you may need to run additional migrations.

Now, run the migration to create the table:

```sh
mix ecto.migrate
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
  import TelemetryUI.Metrics

  [
    metrics: [
      last_value("my_app.users.total_count", description: "Number of users", ui_options: [unit: " users"]),
      counter("phoenix.router_dispatch.stop.duration", description: "Number of requests", unit: {:native, :millisecond}, ui_options: [unit: " requests"]),
      value_over_time("vm.memory.total", unit: {:byte, :megabyte}),
      distribution("phoenix.router_dispatch.stop.duration", description: "Requests duration", unit: {:native, :millisecond}, reporter_options: [buckets: [0, 100, 500, 2000]]),
    ],
    backend: %TelemetryUI.Backend.EctoPostgres{
      repo: MyApp.Repo,
      pruner_threshold: [months: -1],
      pruner_interval_ms: 84_000,
      max_buffer_size: 10_000,
      flush_interval_ms: 10_000
    }
  ]
end
```

Since the config is read once at startup, you need to restart the server of you add new metrics to track.

To see the rendered metrics, you need to add a route to your router.

```elixir
# lib/my_app_web/router.ex
scope "/" do
  get("/metrics", TelemetryUI.Web, [], [assigns: %{telemetry_ui_allowed: true}])
end
```

#### Security

Since it may contain sensitive data, `TelemetryUI` requires a special assign to render the page.

`:telemetry_ui_allowed` must be set to `true` in the `conn` struct before it enters the `TelemetryUI.Web` module.

By using a special assign to control access, you can integrate `TelemetryUI.Web` page with your existing authorization. We can imagine an admin protected section that also gives you access to the `TelemetryUI.Web` page:

```elixir
pipeline :admin_protected do
  plug(MyAppWeb.EnsureCurrentUser)
  plug(MyAppWeb.EnsureRole, :admin)
  plug(:enable_telemetry_ui)
end

def enable_telemetry_ui(conn, _), do: assign(conn, :telemetry_ui_allowed, true)
```

That’s it! You can declare as many metrics as you want and they will render in HTML on your page!

## License

`TelemetryUI` is © 2023 [Mirego](https://www.mirego.com) and may be freely distributed under the [New BSD license](http://opensource.org/licenses/BSD-3-Clause). See the [`LICENSE.md`](https://github.com/mirego/telemetry_ui/blob/master/LICENSE.md) file.

## About Mirego

[Mirego](https://www.mirego.com) is a team of passionate people who believe that work is a place where you can innovate and have fun. We’re a team of [talented people](https://life.mirego.com) who imagine and build beautiful Web and mobile applications. We come together to share ideas and [change the world](http://www.mirego.org).

We also [love open-source software](https://open.mirego.com) and we try to give back to the community as much as we can.
