defmodule TelemetryUI do
  use Supervisor

  alias TelemetryUI.Event

  defmodule State do
    use Agent

    def persist(state),
      do: Enum.each(state, fn {key, value} -> :persistent_term.put(key(key), value) end)

    def get(key), do: :persistent_term.get(key(key))

    defp key(name), do: {:telemetry_ui, name}
  end

  defmodule Section do
    alias TelemetryUI.Web.Component.VegaLite

    defstruct id: nil, title: nil, definition: nil, component: nil

    def cast(section) when is_struct(section, __MODULE__), do: section

    def cast({metric, options}) do
      {component, options} = Keyword.pop_lazy(options, :component, fn -> default_component(metric) end)
      title = metric.description || Event.cast_event_name(metric)

      %__MODULE__{
        id: TelemetryUI.Metric.id(metric),
        title: title,
        component: component,
        definition: {metric, options}
      }
    end

    def cast(metric) when is_struct(metric), do: cast({metric, [{:component, %VegaLite{metric: metric}}]})

    def cast(metric) do
      raise ArgumentError, "metric defintion can either be a %Telemetry.Metrics{} or a 2 elements tuple {%Telemetry.Metrics{}, []}. Got: #{inspect(metric)}"
    end

    defp default_component(metric = %Telemetry.Metrics.Counter{}), do: %VegaLite{metric: metric}
    defp default_component(metric = %Telemetry.Metrics.Sum{}), do: %VegaLite{metric: metric}
    defp default_component(metric = %Telemetry.Metrics.Summary{}), do: %VegaLite{metric: metric}
    defp default_component(metric = %Telemetry.Metrics.LastValue{}), do: %VegaLite{metric: metric}
    defp default_component(_), do: :not_supported
  end

  defmodule Theme do
    @logo """
      <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="currentColor" class="bi bi-symmetry-vertical" viewBox="0 0 16 16">
        <path d="M7 2.5a.5.5 0 0 0-.939-.24l-6 11A.5.5 0 0 0 .5 14h6a.5.5 0 0 0 .5-.5v-11zm2.376-.484a.5.5 0 0 1 .563.245l6 11A.5.5 0 0 1 15.5 14h-6a.5.5 0 0 1-.5-.5v-11a.5.5 0 0 1 .376-.484zM10 4.46V13h4.658L10 4.46z"/>
      </svg>
    """

    defstruct header_color: "#3f84e5", title: "/metrics", logo: @logo, scale: ~w(#3f84e5 #a40e4c  #b20d30 #c17817 #3f784c)
  end

  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  def child_spec(opts),
    do: Supervisor.child_spec(super(opts), id: Keyword.get(opts, :name, __MODULE__))

  @impl Supervisor
  def init(opts) do
    opts[:metrics] || raise ArgumentError, "the :metrics option is required by #{inspect(__MODULE__)}"
    opts[:backend] || raise ArgumentError, "the :backend option is required by #{inspect(__MODULE__)}"

    sections = Enum.map(opts[:metrics], &Section.cast/1)

    metrics =
      sections
      |> Enum.flat_map(
        &Enum.map(List.wrap(&1.definition), fn
          {metric} -> metric
          {metric, _} -> metric
          %{} = metric -> metric
        end)
      )
      |> Enum.uniq_by(&{&1.event_name, &1.tags, Event.cast_report_as(&1)})

    State.persist(%{
      backend: opts[:backend],
      theme: struct!(TelemetryUI.Theme, opts[:theme] || %{}),
      sections: sections
    })

    children = [
      {TelemetryUI.WriteBuffer, backend: opts[:backend]},
      {TelemetryUI.Reporter, metrics: metrics},
      {TelemetryUI.Pruner, backend: opts[:backend]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metric_data(metric, filters) do
    TelemetryUI.Scraper.metric(State.get(:backend), metric, filters)
  end

  def section_by_id(id), do: Enum.find(sections(), &(&1.id === id))
  def theme, do: State.get(:theme)
  def sections, do: State.get(:sections)
end
