defmodule TelemetryUI.Web.View do
  @moduledoc false

  import Phoenix.Component, only: [sigil_H: 2, form: 1]
  import Phoenix.HTML, only: [raw: 1]
  import Phoenix.HTML.Form, only: [hidden_input: 3, select: 4]
  import Phoenix.HTML.Tag, except: [attributes_escape: 1]

  alias TelemetryUI.Web.Component

  js_path = Path.join(__DIR__, "../../../dist/app.js")
  css_path = Path.join(__DIR__, "../../../dist/app.css")

  @external_resource js_path
  @external_resource css_path

  @app_js if File.exists?(js_path), do: File.read!(js_path), else: ""
  @app_css if File.exists?(css_path), do: File.read!(css_path), else: ""
  @app_js_digest "sha512-#{Base.encode64(:crypto.hash(:sha512, @app_js))}"

  def render("app.js"), do: @app_js
  def render("app.css"), do: @app_css
  def app_js_integrity, do: @app_js_digest

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
        <%= if @shared do %>
          <header class="lg:w-1/2 max-w-4xl mx-auto flex justify-between pl-2 py-8" style={theme_color_style(@theme)}>
            <h1 class="text-base font-light font-mono flex items-center justify-center gap-3 pe-none">
              <%= {:safe, @theme.logo} %>
              <%= @theme.title %>
            </h1>
          </header>
        <% else %>
          <div class="bg-white dark:bg-zinc-900 shadow-sm">
            <header class="lg:w-1/2 max-w-4xl mx-auto flex justify-between p-2 mb-4 lg:pr-2 pr-[40px]" style={theme_color_style(@theme)}>
              <h1 class="text-base font-light font-mono flex items-center gap-3 pe-none"><%= {:safe, @theme.logo} %><%= @theme.title %></h1>

              <.form let={f} for={@filter_form} telemetry-component="Form" method="get" class="flex align-items-center">
                <%= hidden_input(f, :page, value: @current_page.id) %>
                <%= select(f, :frame, frame_options(@filters.frame), class: "p-2 rounded-md bg-transparent border-black/10 dark:border-slate-50/10 text-black dark:text-slate-50 text-xs pr-8") %>

                <div class="right-3 absolute top-4 flex items-center gap-2">
                  <%= unless web_option?(@web_options, :disable_share_url, true) do %>
                    <a href={"?share=#{@share}"} target="_blank">
                      <span class="dark:text-zinc-500 text-zinc-200">
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m13.35-.622l1.757-1.757a4.5 4.5 0 00-6.364-6.364l-4.5 4.5a4.5 4.5 0 001.242 7.244" />
                        </svg>
                      </span>
                    </a>
                  <% end %>

                  <%= unless web_option?(@web_options, :disable_theme_switch, true) do %>
                    <button telemetry-component="ThemeSwitch">
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
                  <% end %>
                </div>
              </.form>
            </header>
          </div>
        <% end %>

        <%= if length(@pages) > 1 and not @shared do %>
          <div class="lg:w-1/2 max-w-4xl mx-auto flex flex-wrap gap-3 mb-4">
            <%= for page <- @pages do %>
              <%= if page.id === @current_page.id do %>
                <.page_link page={page} filters={@filters}
                  style={theme_color_style(@theme)}
                  class="px-4 py-1 shadow-sm bg-white dark:bg-zinc-900 font-bold text-primary text-sm dark:text-gray-50"
                />
              <% else %>
                <.page_link page={page} filters={@filters}
                  class="px-4 py-1 bg-white dark:bg-zinc-900 font-bold text-sm dark:text-gray-50 hover:opacity-50"
                />
              <% end %>
            <% end %>
          </div>
        <% end %>

        <div class="lg:w-1/2 max-w-4xl mx-auto md:grid grid-cols-1 gap-4">
          <%= for metric <- @current_page.metrics do %>
            <.component metric={metric} filters={@filters} conn={@conn} theme={@theme} />
          <% end %>
        </div>

        <footer class="p-5 text-center opacity-25 text-xs dark:text-gray-300">
          Built with ♥ by the team @ <a href="https://www.mirego.com">Mirego</a>.
        </footer>
      </body>

      <script type="text/javascript" integrity={app_js_integrity()}><%= raw(render("app.js")) %></script>
    </html>
    """
  end

  defp component(assigns) do
    ~H"""
    <%= Component.render(@metric, %Component.Assigns{filters: @filters, conn: @conn, theme: @theme}) %>
    """
  end

  defp web_option?(options, key, value) do
    Keyword.get(options, key) === value
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
        "filter[to]": if(params.frame !== :custom, do: nil, else: params.to && DateTime.to_iso8601(params.to)),
        "filter[from]": if(params.frame !== :custom, do: nil, else: params.from && DateTime.to_iso8601(params.from))
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    "?" <> URI.encode_query(query)
  end

  defp theme_color_style(theme), do: ~s(color: #{theme.header_color};)

  defp frame_options(frame) do
    for {value, _, _} <- TelemetryUI.Web.Filter.frame_options(frame) do
      {
        String.capitalize(String.replace(to_string(value), "_", " ")),
        value
      }
    end
  end
end
