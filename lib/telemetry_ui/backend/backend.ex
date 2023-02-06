defprotocol TelemetryUI.Backend do
  def insert_event(adapter, value, date, event_name, tags \\ %{}, count \\ 1)
  def prune_events!(adapter, datetime)
  def metric_data(adapter, metric, filters)
end
