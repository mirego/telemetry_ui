defmodule TelemetryUI.Metrics do
  @moduledoc false
  alias Telemetry.Metrics
  alias TelemetryUI.Event
  alias TelemetryUI.Metrics, as: UIMetrics

  @telemetry_metrics [
    {:average, UIMetrics.Average},
    {:average_list, UIMetrics.AverageList},
    {:average_over_time, UIMetrics.AverageOverTime},
    {:count_over_time, UIMetrics.CountOverTime},
    {:count_list, UIMetrics.CountList},
    {:counter, UIMetrics.Counter},
    {:distribution, UIMetrics.Distribution},
    {:last_value, UIMetrics.LastValue},
    {:median, UIMetrics.Median},
    {:median_over_time, UIMetrics.MedianOverTime},
    {:summary, UIMetrics.AverageOverTime},
    {:sum, UIMetrics.Sum},
    {:value_over_time, UIMetrics.AverageOverTime}
  ]

  defmacro __using__(_) do
    quote do
      defstruct id: nil, title: nil, telemetry_metric: nil, data: nil, options: %{}, ui_options: [class: "col-span-full"], unit: nil, tags: [], data_resolver: nil
    end
  end

  def merge_assigns_options(assigns, options) do
    options = Map.merge(options, Map.get(assigns, :options) || %{})
    %{assigns | options: options}
  end

  for {metric_name, metric_struct} <- @telemetry_metrics do
    def unquote(metric_name)(:data, options) do
      {ui_options, options} = Keyword.pop(options, :ui_options, [])
      ui_options = Keyword.merge([class: "col-span-full"], ui_options)

      struct!(unquote(metric_struct),
        id: id(options[:description]),
        title: options[:description],
        options: options[:options],
        unit: options[:unit],
        ui_options: ui_options,
        tags: Keyword.get(options, :tags, []),
        data_resolver: options[:data_resolver],
        telemetry_metric: nil
      )
    end
  end

  for {metric_name, metric_struct} <- @telemetry_metrics do
    def unquote(metric_name)(event_name, options) do
      {ui_options, options} = Keyword.pop(options, :ui_options, [])
      ui_options = Keyword.merge([class: "col-span-full"], ui_options)
      metric = Metrics.summary(event_name, options)

      unit =
        case Keyword.get(ui_options, :unit, metric.unit) do
          {_, unit} -> unit
          unit -> unit
        end

      struct!(unquote(metric_struct),
        id: id(metric),
        title: metric.description || Event.cast_event_name(metric),
        unit: unit,
        options: options[:options],
        ui_options: ui_options,
        tags: metric.tags,
        data_resolver: &{:async, fn -> TelemetryUI.metric_data(&1, metric, &2) end},
        telemetry_metric: metric
      )
    end
  end

  def title(title, options \\ []) do
    {ui_options, options} = Keyword.pop(options, :ui_options, [])
    ui_options = Keyword.merge([class: "col-span-full min-h-auto"], ui_options)

    %UIMetrics.Title{
      title: title,
      options: options,
      ui_options: ui_options
    }
  end

  defp id(name) when is_binary(name) do
    id =
      :sha256
      |> :crypto.hash(name)
      |> Base.url_encode64(padding: false)
      |> String.slice(0..10)

    if String.match?(id, ~r/^[a-zA-Z]/) do
      id
    else
      "a" <> id
    end
  end

  defp id(metric) do
    reporter_options = Enum.reject(List.wrap(Map.get(metric, :reporter_options)), fn {_, value} -> is_function(value) end)
    reporter_options = JSON.encode!(Map.new(reporter_options))

    [
      metric.description,
      metric.name,
      metric.tags,
      reporter_options
    ]
    |> List.flatten()
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join()
    |> id()
  end
end
