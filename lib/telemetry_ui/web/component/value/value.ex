defmodule TelemetryUI.Web.Component.Value do
  use TelemetryUI.Web.Component

  defmodule PrettyFloat do
    @moduledoc """
    Pretty prints a float into either a float or an integer.
    If the float ends with .0, it returns an integer.

    This is used to have a pretty percentage output.

    ## Examples

      iex> PrettyFloat.convert(2.0)
      2
      iex> PrettyFloat.convert(2.2)
      2.2
      iex> PrettyFloat.convert(28)
      28
    """

    def convert(integer) when is_integer(integer), do: integer
    def convert(float) when trunc(float) == float, do: trunc(float)
    def convert(float), do: float
  end

  def draw(assigns) do
    ~H"""
      <div class="bg-white p-4 pt-3 outline outline-offset-0 outline-black/10 outline-1 mb-5">
        <%= if @section.title do %>
          <h2 class="font-light text-lg opacity-80"><%= @section.title %></h2>
        <% end %>

        <div class="mt-2 flex flex-wrap items-center gap-2">
          <%= if tagged_value?(@section) do %>
            <%= for data <- @data do %>
              <div class="flex items-center gap-1 group p-2 border">
                <div class="mr-1 opacity-60 font-mono text-xs group-hover:opacity-100"><%= data.name %></div>
                <div class="font-bold font-mono text-xs"><%= to_value(data.value, data[:precision]) %><span class="font-light text-sm ml-1"><%= if data[:unit], do: data.unit %></span></div>
              </div>
            <% end %>
          <% else %>
            <%= if length(@data) === 1 do %>
              <%= for data <- @data do %>
                <%= if is_nil(data.value) do %>
                  <div class="opacity-25 text-italic text-xs">No data</div>
                <% else %>
                  <div class="font-bold font-mono text-6xl"><%= to_value(data.value, data[:precision]) %><span class="font-light text-lg ml-1"><%= if data[:unit], do: data.unit %></span></div>
                <% end %>
              <% end %>
            <% else %>
              <div class="flex items-center gap-6">
                <%= for data <- @data do %>
                  <div>
                    <div class="mb-1 mr-1 font-light text-sm"><%= data.name %></div>
                    <%= if is_nil(data.value) do %>
                      <div class="opacity-25 text-italic text-xs">No data</div>
                    <% else %>
                      <div class="font-bold font-mono text-4xl"><%= to_value(data.value, data[:precision]) %><span class="font-light text-lg ml-1"><%= if data[:unit], do: data.unit %></span></div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    """
  end

  def to_value(value, precision) when is_float(value) and is_number(precision) do
    PrettyFloat.convert(Float.round(value, precision))
  end

  def to_value(value, _precision) when is_float(value), do: to_value(value, 2)

  def to_value(value, _precision), do: value

  def tagged_value?(section) do
    Enum.any?(List.wrap(section.metric), &Enum.any?(elem(&1, 0).tags))
  end
end
