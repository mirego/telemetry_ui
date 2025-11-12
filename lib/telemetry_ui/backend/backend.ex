defprotocol TelemetryUI.Backend do
  @moduledoc """
  Inserting, fetching and pruning of metrics.

  ## Inserting
  Inserting is called by the internal `WriteBuffer`. It can be grouped depending on the buffer configuration inside the backend struct:

  - `flush_interval_ms`: Time interval before the write buffer calls the backend
  - `max_buffer_size`: Maximum count of events before the write  buffer calls the backend

  ## Fetching
  Fetching is called when rendering metrics in the view. The `filters` argument is a struct with predefined fields: `to`, `from`, `event_name` and `compare`.

  ## Pruning
  Pruning is implemented to keep the datastore clean. Keeping data forever will increase the size of the storage and affect performance.
  - `pruner_threshold`: *Example:* `[months: -1]`. Delete events older than a month.
  - `pruner_interval_ms`: *Example:* 84_000. Time interval for the pruner process to run. The process simply calls `#prune_events!/2`.
  """
  def insert_event(backend, entry)
  def prune_events!(backend, datetime)
  def metric_data(backend, metric, filters)
end
