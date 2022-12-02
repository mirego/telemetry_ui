# Testing

Since TelemetryUI attaches event handlers when it starts the app, it can produce unexpected errors when running `mix test`.

You can disable the metrics handlers by adding a config in `config/test.exs`

```elixir
config :telemetry_ui, disabled: true
```
