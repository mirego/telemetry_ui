defmodule TelemetryUI.MetricsTest do
  use TelemetryUI.Test.DataCase, async: true

  alias TelemetryUI.Metrics

  describe "distribution" do
    test "with float buckets" do
      metric = Metrics.distribution("foo.bar", reporter_options: [buckets: [0.0, 100, 500]])
      assert metric.id
    end
  end
end
