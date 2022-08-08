defmodule TelemetryUI.Web.View do
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
        <%= csrf_meta_tag() %>
        <style><%= raw render("app.css") %></style>
        <title><%= @theme.title %></title>
        <script type="text/javascript"><%= raw(render("app.js")) %></script>
      </head>

      <body><div class="lg:w-1/2 max-w-4xl mx-auto">
        <header class="flex justify-between p-5 lg:px-0 text-white">
          <div class="theme-background" style={"background-color: #{@theme.header_color}"}></div>
          <h1 class="text-xl font-light font-mono flex items-center gap-3">
            <div class="text-white"><%= {:safe, @theme.logo} %></div>
            <%= @theme.title %>
          </h1>

          <.form let={f} for={@filter} telemetry-component="Form" method="get">
            <%= select(f, :frame, frame_options(), class: "p-2 bg-transparent border-white/25 text-white text-sm pr-8") %>
          </.form>
        </header>

        <div>
          <%= for {section, data} <- @metrics_data do %>
            <%= section.component.draw(%{section: section, data: data}) %>
          <% end %>
        </div>

        <script><%= scripts(@sections) %></script>
        <style><%= styles(@sections) %></style>

        <footer class="p-5 text-center opacity-25 text-xs">
          Built with ♥ by the team @ <a href="https://www.mirego.com">Mirego</a>.
        </footer>
      </div></body>
    </html>
    """
  end

  def scripts(sections) do
    sections
    |> Enum.map(& &1.component.script)
    |> Enum.uniq()
    |> Enum.join("\n")
    |> raw()
  end

  def styles(sections) do
    sections
    |> Enum.map(& &1.component.style)
    |> Enum.uniq()
    |> Enum.join("\n")
    |> raw()
  end

  def frame_options do
    for {value, _} <- TelemetryUI.Web.Filter.frame_options() do
      {option_to_label(value), value}
    end
  end

  defp option_to_label(option) do
    String.capitalize(String.replace(to_string(option), "_", " "))
  end
end
