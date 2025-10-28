# Configuration Reference

This guide provides a comprehensive reference for all TelemetryUI configuration options.

## Top-Level Configuration

The configuration passed to `{TelemetryUI, config}` is a keyword list with the following options:

### Required Options

#### `:metrics`

List of metrics to display. Can be specified in three formats:

1. **Simple list** - All metrics in a single unnamed page:

   ```elixir
   metrics: [
     counter("phoenix.router_dispatch.stop.duration"),
     last_value("vm.memory.total")
   ]
   ```

2. **Named pages (2-tuple)** - Group metrics into pages with titles:

   ```elixir
   metrics: [
     {"HTTP", [counter("phoenix.router_dispatch.stop.duration")]},
     {"System", [last_value("vm.memory.total")]}
   ]
   ```

3. **Named pages with UI options (3-tuple)** - Add page-level customization:
   ```elixir
   metrics: [
     {"HTTP", http_metrics(), ui_options: [metrics_class: "grid-cols-4 gap-4"]},
     {"Debug", debug_metrics(), ui_options: [hidden: true]}
   ]
   ```

### Optional Options

#### `:backend`

Backend storage configuration. Currently only EctoPostgres is supported:

```elixir
backend: %TelemetryUI.Backend.EctoPostgres{
  repo: MyApp.Repo,
  pruner_threshold: [months: -1],
  pruner_interval_ms: 84_000,
  max_buffer_size: 10_000,
  flush_interval_ms: 10_000,
  insert_date_bin: Duration.new!(minute: 5),
  verbose: false,
  telemetry_prefix: [:telemetry_ui, :repo],
  telemetry_options: [telemetry_ui_conf: []]
}
```

If not provided, metrics will not be persisted.

#### `:theme`

Customization options for the UI. See [Theme Options](#theme-options) below.

#### `:name`

Atom identifier for the TelemetryUI instance. Required when running multiple instances:

```elixir
name: :admin
```

Default: `:default`

#### `:config`

Function reference for dynamic configuration (enables hot-reloading):

```elixir
# Module and function tuple
config: {MyApp.Telemetry, :config}

# Anonymous function
config: fn -> MyApp.Telemetry.config() end
```

## Backend Options

### EctoPostgres Backend

#### `:repo` (required)

Your application's Ecto repository module:

```elixir
repo: MyApp.Repo
```

#### `:pruner_threshold`

How long to keep historical data. Uses Elixir's date arithmetic:

```elixir
pruner_threshold: [months: -1]   # Keep 1 month of data
pruner_threshold: [days: -7]     # Keep 7 days of data
pruner_threshold: [weeks: -4]    # Keep 4 weeks of data
```

Default: `[months: -1]`

#### `:pruner_interval_ms`

How often to run the pruner (in milliseconds):

```elixir
pruner_interval_ms: 84_000       # Every 84 seconds
pruner_interval_ms: 3_600_000    # Every hour
```

Set to `nil` to disable automatic pruning.

Default: `84_000` (84 seconds)

#### `:max_buffer_size`

Maximum number of events to buffer before flushing to database:

```elixir
max_buffer_size: 10_000
```

Default: `10_000`

#### `:flush_interval_ms`

How often to flush buffered events to database (in milliseconds):

```elixir
flush_interval_ms: 10_000   # Flush every 10 seconds
```

Default: `10_000`

#### `:insert_date_bin`

Time bin size for aggregating events. Uses Elixir's `Duration` struct:

```elixir
insert_date_bin: Duration.new!(minute: 5)    # 5-minute bins
insert_date_bin: Duration.new!(minute: 1)    # 1-minute bins
insert_date_bin: Duration.new!(second: 30)   # 30-second bins
```

Smaller bins = more granular data but more database rows.

Default: `Duration.new!(minute: 5)`

#### `:verbose`

Enable detailed logging for database operations:

```elixir
verbose: true
```

Default: `false`

#### `:telemetry_prefix`

Telemetry event prefix for backend operations:

```elixir
telemetry_prefix: [:telemetry_ui, :repo]
```

Default: `[:telemetry_ui, :repo]`

#### `:telemetry_options`

Additional options passed to telemetry events:

```elixir
telemetry_options: [telemetry_ui_conf: []]
```

Default: `[telemetry_ui_conf: []]`

## Theme Options

Customize the appearance of your metrics dashboard:

### `:primary_color`

Primary color used for the title and first color in charts. Accepts CSS color values:

```elixir
primary_color: "#3F84E5"
primary_color: "rgb(63, 132, 229)"
primary_color: "blue"
```

Default: `"#3F84E5"`

### `:header_color`

Color used for text in the header:

```elixir
header_color: "#28cb87"
```

Default: Same as `:primary_color`

### `:title`

Title displayed in the header and HTML page title:

```elixir
title: "My App Metrics"
```

Default: `"/metrics"`

### `:description`

HTML meta description tag:

```elixir
description: "HTTP, GraphQL and Database metrics"
```

Default: `"Metrics"`

### `:logo`

SVG logo as a string, used for favicon and header:

```elixir
logo: """
<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 16 16">
  <circle cx="8" cy="8" r="8" fill="currentColor"/>
</svg>
"""
```

Default: TelemetryUI's default logo

### `:scale`

List of hex colors used in charts. Colors are used in order:

```elixir
scale: ["#3F84E5", "#7EB26D", "#EAB839", "#6ED0E0"]
```

Default: TelemetryUI's built-in color palette (48 colors)

### `:share_key`

16-character string to enable shareable metrics pages:

```elixir
share_key: "abc123def456ghi7"  # Exactly 16 characters
```

Set to `nil` to disable sharing feature.

Default: `nil`

### `:share_path`

URL path for the shareable metrics page:

```elixir
share_path: "/metrics/public"
```

Must be registered in your router with `TelemetryUI.Web.Share`.

Default: `nil`

### `:frame_options`

Time frame options in the UI selector:

```elixir
frame_options: [
  {:last_30_minutes, 30, :minute},
  {:last_2_hours, 120, :minute},
  {:last_1_day, 1, :day},
  {:last_7_days, 7, :day},
  {:last_1_month, 1, :month},
  {:custom, 0, nil}
]
```

Format: `{identifier_atom, number, time_unit}`

Default: Last 30 minutes, 2 hours, 1 day, 7 days, 1 month, and custom

## Page UI Options

When defining metrics pages with the 3-tuple format, you can pass `ui_options`:

```elixir
{"Page Title", metrics, ui_options: [key: value]}
```

### `:metrics_class`

TailwindCSS grid classes for metrics layout:

```elixir
ui_options: [metrics_class: "grid-cols-4 gap-4"]
ui_options: [metrics_class: "grid-cols-1 md:grid-cols-3 lg:grid-cols-6 gap-2"]
```

Supports all Tailwind responsive variants (`sm:`, `md:`, `lg:`).

Default: `"grid-cols-1 md:grid-cols-3 gap-4"`

### `:hidden`

Hide the page from navigation and main view:

```elixir
ui_options: [hidden: true]
```

Useful for internal metrics or debugging pages.

Default: `false`

### `:styles`

Custom CSS styles applied to the page container:

```elixir
ui_options: [styles: "background-color: #f0f0f0; padding: 20px;"]
```

Default: `""`

## Metric Options

Each metric function supports various options. Common options include:

### `:description`

Human-readable description shown in the UI:

```elixir
counter("phoenix.router_dispatch.stop.duration",
  description: "Total number of HTTP requests"
)
```

### `:unit`

Unit conversion for measurements:

```elixir
unit: {:native, :millisecond}      # Convert native time to ms
unit: {:byte, :megabyte}           # Convert bytes to MB
unit: {:byte, :gigabyte}           # Convert bytes to GB
```

### `:ui_options`

UI customization per metric:

```elixir
ui_options: [
  unit: " requests",                    # Suffix for displayed values
  class: "col-span-2"                   # TailwindCSS classes
]
```

### `:keep`

Filter function to include/exclude events:

```elixir
keep: fn metadata ->
  metadata[:route] not in ~w(/metrics /health)
end
```

### `:tags`

Additional tag dimensions for grouping:

```elixir
tags: [:route]
tags: [:route, :method]
```

### `:tag_values`

Custom function to extract tag values:

```elixir
tag_values: fn metadata ->
  %{custom_tag: extract_custom_value(metadata)}
end
```

### `:reporter_options`

Options passed to the metric reporter:

```elixir
reporter_options: [
  buckets: [0, 100, 500, 2000]    # For distributions
]
```

### `:data_resolver`

Custom function for providing data (instead of telemetry events):

```elixir
data_resolver: fn options ->
  query = from(u in "users",
    select: %{date: u.inserted_at, count: 1},
    where: u.inserted_at >= ^options.from and u.inserted_at <= ^options.to
  )

  {:ok, MyApp.Repo.all(query)}
end
```

See guides/application-data.md for more details.

## Application-Level Configuration

Set in `config/config.exs` or environment-specific configs:

### `:disabled`

Disable all TelemetryUI processes:

```elixir
# config/test.exs
config :telemetry_ui, disabled: true
```

Useful for testing environments.

Default: `false`

## Complete Example

```elixir
[
  # Instance name (for multiple dashboards)
  name: :admin,

  # Metrics configuration
  metrics: [
    {"HTTP", http_metrics(), ui_options: [metrics_class: "grid-cols-4 gap-4"]},
    {"Database", db_metrics(), ui_options: [metrics_class: "grid-cols-2"]},
    {"Internal", internal_metrics(), ui_options: [hidden: true]}
  ],

  # Backend storage
  backend: %TelemetryUI.Backend.EctoPostgres{
    repo: MyApp.Repo,
    pruner_threshold: [months: -1],
    pruner_interval_ms: 3_600_000,
    max_buffer_size: 10_000,
    flush_interval_ms: 10_000,
    insert_date_bin: Duration.new!(minute: 5),
    verbose: false
  },

  # Theme customization
  theme: %{
    primary_color: "#3F84E5",
    header_color: "#3F84E5",
    title: "Admin Metrics Dashboard",
    description: "Real-time application metrics",
    logo: "<svg>...</svg>",
    scale: ["#3F84E5", "#7EB26D", "#EAB839"],
    share_key: "abc123def456ghi7",
    share_path: "/metrics/admin/share",
    frame_options: [
      {:last_hour, 60, :minute},
      {:last_day, 1, :day},
      {:last_week, 7, :day}
    ]
  }
]
```

## See Also

- [Complex Configuration Example](complex-config.md)
- [Custom UI Options](custom-ui.md)
- [Hot-Reloading Configuration](hot-reload.md)
- [Multiple Metrics Endpoints](multi-metrics-endpoints.md)
