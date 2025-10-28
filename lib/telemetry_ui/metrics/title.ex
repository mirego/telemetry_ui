defmodule TelemetryUI.Metrics.Title do
  @moduledoc false

  defstruct title: nil, data_resolver: nil, ui_options: [], options: []

  defimpl TelemetryUI.Web.Component do
    import Phoenix.Component

    def to_image(_metric, _assigns) do
      :error
    end

    def to_html(metric, assigns) do
      assigns = Map.put(assigns, :metric, metric)

      ~H"""
      <div class="pb-2 border-b border-(--accent-color) mb-2">
        <h2 class="text-2xl font-bold">{@metric.title}</h2>
      </div>
      """
    end
  end
end
