defmodule TelemetryUI.Web.View do
  @moduledoc false

  use Phoenix.Component

  alias TelemetryUI.Web.Component
  alias TelemetryUI.Web.Layout

  embed_templates("templates/*")

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

  def component_image(conn, metric, config) do
    Component.to_image(metric, %Component.Assigns{options: metric.options, default_config: config, filters: conn.assigns.filters, theme: conn.assigns.theme})
  end

  defp component_html(assigns) do
    ~H"""
    {Component.to_html(@metric, %Component.Assigns{options: @options, filters: @filters, conn: @conn, theme: @theme})}
    """
  end

  defp frame_options(frame, theme) do
    for {value, _, _} <- TelemetryUI.Web.Filter.frame_options(frame, theme) do
      {
        String.capitalize(String.replace(to_string(value), "_", " ")),
        value
      }
    end
  end
end
