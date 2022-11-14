# Using application data

Sometimes we already have metrics that we want to display without going through the `telemetry` package.
We want to expose the number of users created. The `users` table with the `inserted_at` is perfect for this.
`telemetry_ui` provides a way use the existing metrics helpers with application-defined data:

```elixir
count_over_time(:data,
  description: "Users count",
  unit: " users",
  data_resolver: fn options ->
    query =
      from(
        users in "users",
        select: %{date: users.inserted_at, count: 1},
        where: users.inserted_at >= ^options.from and users.inserted_at <= ^options.to
      )

    {:ok, MyApp.Repo.all(query)}
  end
)
```

The `data_resolver` options is specified here to return the data that will be displayed in the same graph layout as the `telemetry_ui_events` entries.
The built-in metrics uses the same `data_resolver` options: `data_resolver: &{:async, fn -> TelemetryUI.metric_data(&1, metric, &2) end}`.
