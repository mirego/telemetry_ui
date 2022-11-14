# Multiple metrics endpoints

The `/metrics` endpoint exposes different pages of metrics. We can also have multiple metrics endpoint.
The benefit is to have different metrics exposed with different permissions. Here is an example:

We have our router defining routes with different `telemetry_ui_name` Plug.Conn assign.

```elixir
scope "/admin" do
  pipe_through [EnsureAdmin]

  get("/metrics", TelemetryUI.Web, :index, assigns: %{telemetry_ui_name: :admin})
end

scope "/user_dashboard" do
  pipe_through [EnsureUser]

  get("/metrics", TelemetryUI.Web, :index, assigns: %{telemetry_ui_name: :user_dashboard})
end
```

```elixir
defmodule MyApp.Telemetry do
  import TelemetryUI.Metrics

  def admin do
    [
      name: :admin,
      metrics: [
        {"Memory", [value_over_time("vm.memory.total", unit: {:byte, :megabyte})]}
      ],
      backend: backend(),
      theme: %{header_color: "purple", title: "Admin metrics"}
    ]
  end

  def user_dashboard do
    [
      name: :user_dashboard,
      metrics: [
        {"Followers", [count_over_time("myapp.users.new_follower")]}
      ],
      backend: backend(),
      theme: %{header_color: "blue", title: "User dashboard metrics"}
    ]
  end

  defp backend do
    %TelemetryUI.Backend.EctoPostgres{
      repo: MyApp.Repo,
      pruner_threshold: [months: -1],
      pruner_interval_ms: 84_000,
      max_buffer_size: 1,
      flush_interval_ms: 1,
      verbose: true
    }
  end
end
```

Don’t forget to start all `TelemetryUI` process in `application.ex`:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      # ...
      {TelemetryUI, MyApp.Telemetry.admin()},
      {TelemetryUI, MyApp.Telemetry.user_dashboard()}
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```
