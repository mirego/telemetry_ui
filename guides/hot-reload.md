# Hot-Reloading Configuration

TelemetryUI supports hot-reloading of configuration without restarting your application. This is useful during development or when you need to dynamically adjust metrics in production.

## Setup for Hot-Reload

### 1. Use Dynamic Configuration

Instead of passing configuration directly, pass a function reference:

```elixir
# lib/my_app/application.ex
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      MyApp.Repo,
      MyAppWeb.Endpoint,
      # Pass function reference instead of calling it
      {TelemetryUI, config: {MyApp.Telemetry, :config}}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
  end
end
```

You can also use an anonymous function:

```elixir
{TelemetryUI, config: fn -> MyApp.Telemetry.config() end}
```

### 2. Define Your Configuration Module

```elixir
# lib/my_app/telemetry.ex
defmodule MyApp.Telemetry do
  import TelemetryUI.Metrics

  def config do
    [
      metrics: [
        {"HTTP", http_metrics()},
        {"Database", database_metrics()}
      ],
      backend: backend(),
      theme: theme()
    ]
  end

  defp http_metrics do
    [
      counter("phoenix.router_dispatch.stop.duration",
        description: "Number of requests",
        unit: {:native, :millisecond},
        ui_options: [unit: " requests"]
      ),
      average_over_time("phoenix.router_dispatch.stop.duration",
        description: "Average request duration",
        unit: {:native, :millisecond}
      )
    ]
  end

  defp database_metrics do
    [
      average("myapp.repo.query.total_time",
        description: "Average query time",
        unit: {:native, :millisecond}
      )
    ]
  end

  defp backend do
    %TelemetryUI.Backend.EctoPostgres{
      repo: MyApp.Repo,
      pruner_threshold: [months: -1],
      pruner_interval_ms: 84_000,
      max_buffer_size: 10_000,
      flush_interval_ms: 10_000
    }
  end

  defp theme do
    %{
      title: "My App Metrics",
      primary_color: "#3F84E5"
    }
  end
end
```

## Reloading Configuration

### Manual Reload

To reload the configuration manually (e.g., from IEx console or a custom endpoint):

```elixir
# For default TelemetryUI instance
TelemetryUI.reload(config: {MyApp.Telemetry, :config})

# For named instance
TelemetryUI.reload(config: {MyApp.Telemetry, :config}, name: :admin)
```

The `reload/1` function will:

1. Stop all running TelemetryUI child processes (Reporter, WriteBuffer, Pruner)
2. Re-evaluate the configuration function
3. Restart all processes with the new configuration

### Automatic Reload with Plug

You can add a Plug to automatically reload configuration on specific requests. This is useful for development:

```elixir
# lib/my_app_web/endpoint.ex
if code_reloading? do
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
    plug(TelemetryUI.Reloader, config: {MyApp.Telemetry, :config})
end
```

**Warning:** Only use `TelemetryUI.Reloader` in development. Reloading on every request in production will impact performance.

## Limitations

- New telemetry event handlers will be attached, but existing handlers continue to collect data
- Historical data is preserved; only the visualization configuration changes
- Database schema changes (new backends, different repos) require a full application restart

## Multiple Named Instances

When using named instances, reload each separately:

```elixir
# Reload admin dashboard
TelemetryUI.reload(config: {MyApp.Telemetry, :admin_config}, name: :admin)

# Reload user dashboard
TelemetryUI.reload(config: {MyApp.Telemetry, :user_config}, name: :user_dashboard)
```
