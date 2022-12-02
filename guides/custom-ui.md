# Custom UI

`telemetry_ui` offers many way to customize the layouts, colors and components of your dashboard.

## Theme

The `theme` option of you configuration can be customized:

```elixir
[
  metrics: [
    {"Users", [count_over_time("myapp.users.created")]}
  ],
  backend: backend(),
  theme: %{
    header_color: "blue",
    title: "User dashboard metrics"
  }
]
```

Here is the list of available options:

- `header_color`: A CSS color used as the text color in the header
- `title`: The title used in the header
- `logo`: An SVG binary used in the header and the favicon
- `scale`: Available colors used in graph. The colors are used in the same order they are defined in.
- `share_key`: 16 characters key that enable the sharing of a dashboard page. The share feature is hidden when the option is `nil`
- `frame_options`: List of options for the time frame select in the UI. Format: `{atom_identitifer, number, unit}` `{:last_3_minutes, 3, :minute}`

## Layout

The list of metrics can also be customized with TailwindCSS classes. Here is an example with 2 metrics side-by-side in a grid:

```elixir
metrics = [
  distribution("my_app.repo.query.total_time",
    reporter_options: [buckets: [0, 4, 10, 50]],
    ui_options: [class: "col-span-2"],
    unit: {:native, :millisecond}
  ),
  distribution("phoenix.router_dispatch.stop.duration",
    reporter_options: [buckets: [0, 40, 100, 500]],
    ui_options: [class: "col-span-2"],
    unit: {:native, :millisecond}
  ),
  distribution("phoenix.router_dispatch.stop.duration",
    tags: [:route],
    reporter_options: [buckets: [0, 40, 100, 500]],
    ui_options: [class: "col-span-full"],
    unit: {:native, :millisecond}
  )
]

[
  metrics: [
    {"Metrics layout page", metrics, ui_options: [metrics_class: "grid-cols-4 gap-4"]}
  ],
  backend: #...
  theme: #...
]
```

All grid classes are available with `sm` and `lg` variant to support mobile and desktop viewports.
