defmodule TelemetryUI do
  use Supervisor

  defmodule State do
    use Agent

    def persist(state),
      do: Enum.each(state, fn {key, value} -> :persistent_term.put(key(key), value) end)

    def get(key), do: :persistent_term.get(key(key))

    defp key(name), do: {:telemetry_ui, name}
  end

  defmodule Section do
    alias Telemetry.Metrics
    alias TelemetryUI.Web.Component

    defstruct title: nil, layout: %{}, metric: [], component: nil

    def cast(section) when is_struct(section, __MODULE__), do: section

    def cast({metric, options}) do
      {component, options} = Keyword.pop_lazy(options, :component, fn -> default_component(metric) end)
      {layout, options} = Keyword.pop(options, :layout, %{})
      options = Enum.into(Keyword.merge(options, default_options(metric)), %{})
      title = metric.description || Enum.join(metric.name, ".")

      %__MODULE__{title: title, layout: layout, component: component, metric: {metric, options}}
    end

    def cast(metric) when is_struct(metric) do
      cast({metric, [{:component, default_component(metric)} | default_options(metric)]})
    end

    def cast(metric) do
      raise ArgumentError, "metric defintion can either be a %Telemetry.Metrics{} or a 2 elements tuple {%Telemetry.Metrics{}, []}. Got: #{inspect(metric)}"
    end

    defp default_component(metric) when is_struct(metric, Metrics.Distribution), do: Component.Chart
    defp default_component(metric) when is_struct(metric, Metrics.Summary), do: Component.Chart
    defp default_component(_metric), do: Component.Value

    defp default_options(metric) when is_struct(metric, Metrics.Distribution), do: [type: "bar", query_aggregate: {:list, :average}]
    defp default_options(metric) when is_struct(metric, Metrics.Summary), do: [type: "lines", query_aggregate: {:list, :average}]
    defp default_options(metric) when is_struct(metric, Metrics.LastValue), do: [unit: metric.unit]
    defp default_options(metric) when is_struct(metric, Metrics.Sum), do: [unit: metric.unit]
    defp default_options(_metric), do: []
  end

  defmodule Theme do
    defstruct header_color: "#555", title: "/metrics", logo: ~s(
      <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="currentColor" class="bi bi-symmetry-vertical" viewBox="0 0 16 16">
        <path d="M7 2.5a.5.5 0 0 0-.939-.24l-6 11A.5.5 0 0 0 .5 14h6a.5.5 0 0 0 .5-.5v-11zm2.376-.484a.5.5 0 0 1 .563.245l6 11A.5.5 0 0 1 15.5 14h-6a.5.5 0 0 1-.5-.5v-11a.5.5 0 0 1 .376-.484zM10 4.46V13h4.658L10 4.46z"/>
      </svg>)
  end

  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  def child_spec(opts),
    do: Supervisor.child_spec(super(opts), id: Keyword.get(opts, :name, __MODULE__))

  @impl Supervisor
  def init(opts) do
    opts[:metrics] || raise ArgumentError, "the :metrics option is required by #{inspect(__MODULE__)}"
    opts[:adapter] || raise ArgumentError, "the :adapter option is required by #{inspect(__MODULE__)}"

    sections = Enum.map(opts[:metrics], &Section.cast/1)

    metrics =
      sections
      |> Enum.flat_map(
        &Enum.map(List.wrap(&1.metric), fn
          {metric} -> metric
          {metric, _} -> metric
          %{} = metric -> metric
        end)
      )
      |> Enum.uniq_by(&{&1.event_name, &1.tags, &1.reporter_options})

    State.persist(%{
      adapter: opts[:adapter],
      theme: struct!(TelemetryUI.Theme, opts[:theme] || %{}),
      sections: sections
    })

    children = [
      {TelemetryUI.WriteBuffer, Map.put(Enum.into(opts[:write_buffer], %{}), :adapter, opts[:adapter])},
      {TelemetryUI.Reporter, metrics: metrics},
      {TelemetryUI.Pruner, Map.put(Enum.into(opts[:pruner], %{}), :adapter, opts[:adapter])}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def adapter, do: State.get(:adapter)
  def theme, do: State.get(:theme)
  def sections, do: State.get(:sections)
end
