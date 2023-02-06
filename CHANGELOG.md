# Changelog

## v2.0.0 (2023-01-25)

### BREAKING CHANGES

- `report_as` option has been removed in favor of using a unique "name": https://hexdocs.pm/telemetry_metrics/Telemetry.Metrics.html#module-filtering-on-metadata
- The migration number 3 deletes all row with a non null `report_as` before changing the unique index. You can do a manual data migration before executing the `telemetry_ui` migration if you don’t want to lose data.
