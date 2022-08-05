defmodule TelemetryUI.Web.Component.Chart do
  use TelemetryUI.Web.Component

  def draw(assigns) do
    ~H"""
    <div class="bg-white p-4 pt-3 outline outline-offset-0 outline-black/10 outline-1 mb-5">
      <%= if @section.title do %>
        <h2 class="font-light text-lg opacity-80"><%= @section.title %></h2>
      <% end %>

      <%= {:safe, chart(@section.layout, @data)} %>
    </div>
    """
  end

  defp chart(layout, data) do
    ~s(<div data-layout="#{data_json(layout)}" data-payload="#{data_json(data)}" telemetry-component="Chart"></div>)
  end

  defp data_json(data) do
    data
    |> Jason.encode!()
    |> Plug.HTML.html_escape()
  end
end
