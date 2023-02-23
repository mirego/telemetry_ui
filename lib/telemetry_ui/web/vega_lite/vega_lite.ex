defmodule TelemetryUI.Web.VegaLite do
  @moduledoc false

  use Phoenix.HTML
  use Phoenix.Component

  def draw(spec, metric) do
    assigns = %{spec: spec, metric: metric}

    ~H"""
    <div class="relative flex flex-col bg-white dark:bg-black/40 text-slate dark:text-white p-3 pt-2 shadow min-h-[200px] h-full">
      <.title title={@metric.title} />
      <.container id={@metric.id} />
      <.legend id={@metric.id} />
      <.loading_view id={@metric.id} />
      <.empty_view id={@metric.id} />
      <.fullscreen_button id={@metric.id} />
    </div>

    <.script spec={@spec} id={@metric.id} />
    """
  end

  defp fullscreen_button(assigns) do
    ~H"""
    <button role="button" telemetry-component="ToggleFullscreen" data-view-id={@id} class="absolute right-0 top-0 py-2 px-3 block hover:opacity-50">
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-3 h-3">
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M3.75 3.75v4.5m0-4.5h4.5m-4.5 0L9 9M3.75 20.25v-4.5m0 4.5h4.5m-4.5 0L9 15M20.25 3.75h-4.5m4.5 0v4.5m0-4.5L15 9m5.25 11.25h-4.5m4.5 0v-4.5m0 4.5L15 15"
        />
      </svg>
    </button>
    """
  end

  def script(assigns) do
    ~H"""
    <script>
      document.addEventListener("DOMContentLoaded", function() {
        window.drawChart('#<%= @id %>', <%= raw VegaLite.Export.to_json(@spec) %>)
      })
    </script>
    """
  end

  defp title(assigns) do
    ~H"""
    <%= if @title do %>
      <h2 class="flex items-baseline gap-2 text-base opacity-80 mb-2">
        <%= @title %>
      </h2>
    <% end %>
    """
  end

  defp container(assigns) do
    ~H"""
    <div id={@id} class="hidden grow w-full"></div>
    """
  end

  defp legend(assigns) do
    ~H"""
    <div id={@id <> "-legend"} class="select-none hidden grow w-full mt-2 flex flex-wrap gap-2 text-xs font-mono text-neutral-900 dark:text-neutral-50"></div>
    """
  end

  defp loading_view(assigns) do
    ~H"""
    <div id={@id <> "-loading"} class="absolute top-[40px] left-0 flex flex-col grow items-center justify-center py-3 w-full">
      <div class="p-3 px-5 gap-1 flex flex-col grow items-center">
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="animation-loading opacity-20" width="30px">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182m0-4.991v4.99"
          />
        </svg>
      </div>
    </div>
    """
  end

  defp empty_view(assigns) do
    ~H"""
    <div id={@id <> "-empty"} class="absolute top-[40px] left-0 hidden flex flex-col grow items-center justify-center py-3 w-full">
      <div class="p-3 px-5 gap-1 shadow-md dark:shadow-black rounded-md bg-gray-50 dark:bg-black/40 flex flex-col grow items-center ">
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="opacity-20" width="30px">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9.75 9.75l4.5 4.5m0-4.5l-4.5 4.5M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>

        <span class="opacity-90 text-sm font-bold text-center">No data</span>
      </div>
    </div>
    """
  end
end
