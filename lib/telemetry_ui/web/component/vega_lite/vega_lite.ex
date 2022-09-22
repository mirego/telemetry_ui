defmodule TelemetryUI.Web.Component.VegaLite do
  defstruct spec: nil

  defimpl TelemetryUI.Web.Component do
    use Phoenix.HTML
    use Phoenix.Component

    alias TelemetryUI.Web.Component.VegaLite.Spec

    def metric_data(_, metric, params) do
      {:async, fn -> TelemetryUI.metric_data(metric, params) end}
    end

    def draw(_component, assigns = %TelemetryUI.Web.Component.Assigns{}) do
      ~H"""
      <% spec = to_spec(assigns) %>

      <%= if is_struct(spec, VegaLite) do %>
        <div class="flex flex-col bg-white dark:bg-zinc-900 text-slate dark:text-white p-3 pt-2 shadow min-h-[170px]">
          <.title metric={@metric} />
          <.empty_view metric={@metric} />
          <.container metric={@metric} />
          <.legend metric={@metric} />
        </div>

        <.script spec={spec} metric={@metric} />
      <% end %>
      """
    end

    defp script(assigns) do
      ~H"""
        <script>
          document.addEventListener("DOMContentLoaded", function() {
            window.drawChart('#<%= @metric.id %>', <%= raw VegaLite.Export.to_json(@spec) %>)
          })
        </script>
      """
    end

    defp title(assigns) do
      ~H"""
      <%= if @metric.title do %>
        <h2 class="flex items-baseline gap-2 text-base opacity-80 mb-2">
          <%= @metric.title %>
        </h2>
      <% end %>
      """
    end

    defp container(assigns) do
      ~H"""
      <div id={@metric.id} class="hidden grow w-full"></div>
      """
    end

    defp legend(assigns) do
      ~H"""
      <div id={@metric.id <> "-legend"} class="hidden grow w-full ml-2 mt-2 flex flex-wrap gap-2 text-xs font-mono text-zinc-900 dark:text-zinc-50"></div>
      """
    end

    defp empty_view(assigns) do
      ~H"""
      <div id={@metric.id <> "-empty"} class="hidden flex flex-col grow items-center justify-center gap-1 py-3 w-full">
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="opacity-20" width="30px">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9.75 9.75l4.5 4.5m0-4.5l-4.5 4.5M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>

        <span class="opacity-90 text-sm font-bold text-center">No data</span>
        <span class="opacity-40 text-sm text-center">Try to change the time filter</span>
      </div>
      """
    end

    defp to_spec(assigns) do
      uri = URI.parse(assigns.conn.request_path <> "?" <> assigns.conn.query_string)

      source_query = Map.put(URI.decode_query(uri.query), "metric-data", assigns.metric.id)
      source_uri = %{uri | query: URI.encode_query(source_query)}

      data = %{
        source: URI.to_string(source_uri)
      }

      Spec.build(assigns.metric, data, assigns)
    end
  end
end
