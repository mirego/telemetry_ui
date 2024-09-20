defmodule TelemetryUI.Web.VegaLite do
  @moduledoc false
  use Phoenix.Component

  def draw(spec, metric, assigns) do
    assigns = Map.merge(assigns, %{spec: spec, metric: metric})

    ~H"""
    <div class="vega-lite-metric group relative flex flex-col bg-white dark:bg-black/40 text-slate dark:text-white p-3 border border-black/5 dark:border-white/20 rounded-lg min-h-[220px] h-full">
      <%= if TelemetryUI.VegaLiteToImage.enabled?() && @conn.assigns[:share] && @theme.share_path do %>
        <img loading="lazy" class="hidden" src={@theme.share_path <> "?id=#{@metric.id}.png&share=" <> @conn.assigns.share} />
      <% end %>

      <.title id={@metric.id} title={@metric.title} />
      <.container id={@metric.id} />
      <.legend :if={Map.has_key?(@options, :legend) && @options.legend} id={@metric.id} />
      <.loading_view id={@metric.id} />
      <.empty_view id={@metric.id} />
      <.close_fullscreen_button id={@metric.id} />
      <.fullscreen_button id={@metric.id} />
    </div>

    <.script spec={@spec} id={@metric.id} />
    """
  end

  defp fullscreen_button(assigns) do
    ~H"""
    <button role="button" telemetry-component="ToggleFullscreen" data-view-id={@id} class="group-hover:block absolute right-[-55px] top-0 py-2 px-3 hidden hover:opacity-50">
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

  defp close_fullscreen_button(assigns) do
    ~H"""
    <button role="button" telemetry-component="ToggleFullscreen" data-view-id={@id} class="close-fullscreen-button absolute right-0 top-0 py-2 px-3 hidden hover:opacity-50">
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-6 h-6">
        <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
      </svg>
    </button>
    """
  end

  def script(assigns) do
    ~H"""
    <script>
      document.addEventListener("DOMContentLoaded", function() {
        window.drawChart('#<%= @id %>', <%= {:safe, VegaLite.Export.to_json(@spec)} %>)
      })
    </script>
    """
  end

  defp title(assigns) do
    ~H"""
    <%= if @title do %>
      <h2 id={@id <> "-title"} class="flex items-baseline gap-2 text-base opacity-80 mb-2 ml-[7px]">
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
    <div id={@id <> "-loading"} class="absolute top-[50px] left-0 flex flex-col grow items-center justify-center py-3 w-full">
      <div class="py-3 px-5 gap-1 flex flex-col grow items-center">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" fill="currentColor" class="animation-loading opacity-20" width="24px">
          <path d="M512 1024c-69.1 0-136.2-13.5-199.3-40.2C251.7 958 197 921 150 874c-47-47-84-101.7-109.8-162.7C13.5 648.2 0 581.1 0 512c0-19.9 16.1-36 36-36s36 16.1 36 36c0 59.4 11.6 117 34.6 171.3 22.2 52.4 53.9 99.5 94.3 139.9 40.4 40.4 87.5 72.2 139.9 94.3C395 940.4 452.6 952 512 952c59.4 0 117-11.6 171.3-34.6 52.4-22.2 99.5-53.9 139.9-94.3 40.4-40.4 72.2-87.5 94.3-139.9C940.4 629 952 571.4 952 512c0-59.4-11.6-117-34.6-171.3a440.45 440.45 0 0 0-94.3-139.9 437.71 437.71 0 0 0-139.9-94.3C629 83.6 571.4 72 512 72c-19.9 0-36-16.1-36-36s16.1-36 36-36c69.1 0 136.2 13.5 199.3 40.2C772.3 66 827 103 874 150c47 47 83.9 101.8 109.7 162.7 26.7 63.1 40.2 130.2 40.2 199.3s-13.5 136.2-40.2 199.3C958 772.3 921 827 874 874c-47 47-101.8 83.9-162.7 109.7-63.1 26.8-130.2 40.3-199.3 40.3z" />
        </svg>
      </div>
    </div>
    """
  end

  defp empty_view(assigns) do
    ~H"""
    <div id={@id <> "-empty"} class="absolute top-[90px] left-0 hidden flex flex-col grow items-center justify-center py-3 w-full">
      <div class="flex flex-col items-center">
        <span class="opacity-40 text-sm text-center">No data</span>
      </div>
    </div>
    """
  end
end
