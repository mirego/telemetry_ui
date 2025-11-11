# Changelog

## v5.3.0 (2025-11-10)

### Bug Fixes

- Fix integer overflow crash in `insert_event` by changing `count` column from `int4` to `bigint` (migration V04)
  - High-traffic events that accumulate more than 2.1B counts in a single time bucket would cause PostgreSQL "integer out of range" errors
  - Existing installations should run migration V04 to upgrade

## v5.2.0 (2025-10-06)

### Features

- Add `TelemetryUI.Reloader` plug for hot-reloading metrics configuration
- Add `:config` option to support dynamic configuration via MFA tuple or function
- Use Ecto built-in `avg/1` and `sum/1` functions instead of fragments
- Fix compare aggregate percentage formatting
- Update Tailwind CSS to v4
- Update Vega dependencies

## v5.0.0 (2025-01-04)

### BREAKING CHANGES

- Minimum Elixir version raised to `~> 1.17` (requires `Duration` module)
- Minimum PostgreSQL version raised to 16 (requires `date_bin` function)
- `vega_lite_convert` upgraded to `~> 1.0` and is now a required dependency (no longer optional)
- `vix` dependency removed

## v4.0.0 (2023-06-26)

### BREAKING CHANGES

- `TelemetryUI.Web.Component.to_image` implementation of VegaLite components has been extracted to a standalone library to remove hard dependency on rustler precompiled and vix.

### Features

- Interval refresh for live charts update :tada:

## v3.0.0 (2023-04-26)

### BREAKING CHANGES

- `TelemetryUI.Web.Component` now can render image, so the protocol has a `to_html` and a `to_image` instead of the single `render` function
- `TelemetryUI.Web` controller does not include the "share" param parsing anymore. If you want to have sharable URL, you need to add `TelemetryUI.Web.Share` controller
  in your router and the `share_path` config in your theme.

### Features

- Standalone `TelemetryUI.Web.Share` controller: Simplify sharing features
- Images: `vl-convert` integration with Rust to be able to build image urls of VegaLite components
- Digest `metric_images`: Add images in the digest message sent to Slack

## v2.0.0 (2023-01-25)

### BREAKING CHANGES

- `report_as` option has been removed in favor of using a unique "name": https://hexdocs.pm/telemetry_metrics/Telemetry.Metrics.html#module-filtering-on-metadata
- The migration number 3 deletes all row with a non null `report_as` before changing the unique index. You can do a manual data migration before executing the `telemetry_ui` migration if you don’t want to lose data.
