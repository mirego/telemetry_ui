defmodule TelemetryUI.Web.View do
  @moduledoc false

  use Phoenix.Component

  alias TelemetryUI.Web.Component

  embed_templates("template.html")

  js_path = :telemetry_ui |> :code.priv_dir() |> Path.join("static/assets/app.js")
  css_path = :telemetry_ui |> :code.priv_dir() |> Path.join("static/assets/app.css")

  @external_resource js_path
  @external_resource css_path

  @app_js if File.exists?(js_path), do: File.read!(js_path), else: ""
  @app_css if File.exists?(css_path), do: File.read!(css_path), else: ""
  @app_js_digest "sha512-#{Base.encode64(:crypto.hash(:sha512, @app_js))}"

  def render("app.js"), do: @app_js
  def render("app.css"), do: @app_css
  def app_js_integrity, do: @app_js_digest

  def favicon(theme) do
    logo =
      theme.logo
      |> String.trim()
      |> String.replace("<", "%3C")
      |> String.replace(">", "%3E")
      |> String.replace("#", "%23")
      |> String.replace(~s("), "'")

    {:safe, "data:image/svg+xml,#{logo}"}
  end

  def render("index.html", assigns), do: template(assigns)

  defp version do
    case :application.get_key(:telemetry_ui, :vsn) do
      {:ok, current} ->
        List.to_string(current)

      _ ->
        "dev"
    end
  end

  defp filter_datetime_format(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  end

  def component_image(conn, metric, extension, config) do
    Component.to_image(metric, extension, %Component.Assigns{options: metric.options, default_config: config, filters: conn.assigns.filters, theme: conn.assigns.theme})
  end

  defp component_html(assigns) do
    ~H"""
    <%= Component.to_html(@metric, %Component.Assigns{options: @options, filters: @filters, conn: @conn, theme: @theme}) %>
    """
  end

  defp theme_switch(assigns) do
    ~H"""
    <button telemetry-component="ThemeSwitch" class="flex items-center gap-1 dark:text-neutral-200 hover:text-[var(--accent-color)] transition-colors text-neutral-500 text-xs">
      <span class="dark:block hidden">
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M12 3v2.25m6.364.386l-1.591 1.591M21 12h-2.25m-.386 6.364l-1.591-1.591M12 18.75V21m-4.773-4.227l-1.591 1.591M5.25 12H3m4.227-4.773L5.636 5.636M15.75 12a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0z"
          />
        </svg>
      </span>

      <span class="dark:hidden block">
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M21.752 15.002A9.718 9.718 0 0118 15.75c-5.385 0-9.75-4.365-9.75-9.75 0-1.33.266-2.597.748-3.752A9.753 9.753 0 003 11.25C3 16.635 7.365 21 12.75 21a9.753 9.753 0 009.002-5.998z"
          />
        </svg>
      </span>
      <%= if assigns[:inner_block] do %>
        <%= render_slot(@inner_block) %>
      <% end %>
    </button>
    """
  end

  defp page_link(assigns) do
    ~H"""
    <a href={page_href(@page.id, @filters)} class={@class} style={Map.get(assigns, :style)}>
      <%= @page.title %>
    </a>
    """
  end

  defp page_href(page_id, params) do
    query =
      %{
        "filter[page]": page_id,
        "filter[frame]": params.frame,
        "filter[to]": if(params.frame === :custom, do: params.to && DateTime.to_iso8601(params.to)),
        "filter[from]": if(params.frame === :custom, do: params.from && DateTime.to_iso8601(params.from))
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    "?" <> URI.encode_query(query)
  end

  defp theme_color_style(theme), do: ~s(color: #{theme.header_color}; --accent-color: #{theme.header_color};)

  defp frame_options(frame, theme) do
    for {value, _, _} <- TelemetryUI.Web.Filter.frame_options(frame, theme) do
      {
        String.capitalize(String.replace(to_string(value), "_", " ")),
        value
      }
    end
  end
end
