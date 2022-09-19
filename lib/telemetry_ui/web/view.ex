defmodule TelemetryUI.Web.View do
  @moduledoc false

  use Phoenix.HTML

  import Phoenix.LiveView.Helpers

  js_path = Path.join(__DIR__, "../../../dist/app.js")
  css_path = Path.join(__DIR__, "../../../dist/app.css")

  @external_resource js_path
  @external_resource css_path

  @app_js if File.exists?(js_path), do: File.read!(js_path), else: ""
  @app_css if File.exists?(css_path), do: File.read!(css_path), else: ""

  def render("app.js"), do: @app_js
  def render("app.css"), do: @app_css

  def render("index.html", assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta http-equiv="X-UA-Compatible" content="IE=edge" />
        <title><%= @theme.title %></title>
        <style><%= raw render("app.css") %></style>
        <%= csrf_meta_tag() %>
      </head>

      <body class="bg-zinc-50 dark:bg-zinc-800">
        <div class="bg-white dark:bg-zinc-900 shadow-sm">
          <header class="lg:w-1/2 max-w-4xl mx-auto flex justify-between p-2 mb-4 lg:pr-2 pr-[40px]" style={theme_color_style(@theme)}>
            <h1 class="text-base font-light font-mono flex items-center gap-3"><%= {:safe, @theme.logo} %><%= @theme.title %></h1>

            <.form let={f} for={@filter} telemetry-component="Form" method="get" class="flex align-items-center">
              <%= hidden_input(f, :page, value: @current_page.id) %>
              <%= select(f, :frame, frame_options(), class: "p-2 rounded-md bg-transparent border-black/10 dark:border-slate-50/10 text-black dark:text-slate-50 text-xs pr-8") %>

              <button telemetry-component="ThemeSwitch" class="right-3 absolute top-4">
                <span class="dark:block hidden text-zinc-500">
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 3v2.25m6.364.386l-1.591 1.591M21 12h-2.25m-.386 6.364l-1.591-1.591M12 18.75V21m-4.773-4.227l-1.591 1.591M5.25 12H3m4.227-4.773L5.636 5.636M15.75 12a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0z" />
                  </svg>
                </span>

                <span class="dark:hidden block text-zinc-200">
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M21.752 15.002A9.718 9.718 0 0118 15.75c-5.385 0-9.75-4.365-9.75-9.75 0-1.33.266-2.597.748-3.752A9.753 9.753 0 003 11.25C3 16.635 7.365 21 12.75 21a9.753 9.753 0 009.002-5.998z" />
                  </svg>
                </span>
              </button>
            </.form>
          </header>
        </div>

        <%= if length(@pages) > 1 do %>
          <div class="lg:w-1/2 max-w-4xl mx-auto flex flex-wrap gap-3 mb-4">
            <%= for page <- @pages do %>
              <%= if page.id === @current_page.id do %>
                <.page_link page={page} params={@params}
                  style={theme_color_style(@theme)}
                  class="px-4 py-1 shadow-sm bg-white dark:bg-zinc-900 font-bold text-primary text-sm dark:text-gray-50"
                />
              <% else %>
                <.page_link page={page} params={@params}
                  class="px-4 py-1 bg-white dark:bg-zinc-900 font-bold text-sm dark:text-gray-50 hover:opacity-50"
                />
              <% end %>
            <% end %>
          </div>
        <% end %>

        <div class="lg:w-1/2 max-w-4xl mx-auto md:grid grid-cols-1 gap-4">
          <%= for metric <- @current_page.metrics do %>
            <%= TelemetryUI.Web.Component.draw(
              metric.web_component,
              %TelemetryUI.Web.Component.Assigns{filters: @filter_options, metric: metric, conn: @conn, theme: @theme}
            ) %>
          <% end %>
        </div>

        <footer class="p-5 text-center opacity-25 text-xs dark:text-gray-300">
          Built with ♥ by the team @ <a href="https://www.mirego.com">Mirego</a>.
        </footer>
      </body>

      <script type="text/javascript"><%= raw(render("app.js")) %></script>
    </html>
    """
  end

  defp page_link(assigns) do
    ~H"""
    <a href={page_href(@page.id, @params)} class={@class} style={Map.get(assigns, :style)}>
      <%= @page.title %>
    </a>
    """
  end

  defp page_href(page_id, params) do
    "?filter[page]=#{page_id}&filter[frame]=#{params.frame}"
  end

  defp theme_color_style(theme), do: ~s(color: #{theme.header_color};)

  defp frame_options do
    for {value, _} <- TelemetryUI.Web.Filter.frame_options() do
      {
        String.capitalize(String.replace(to_string(value), "_", " ")),
        value
      }
    end
  end
end
