# Changelog

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
