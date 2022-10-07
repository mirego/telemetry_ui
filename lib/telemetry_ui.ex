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

  defmodule Page do
    defstruct id: nil, title: nil, metrics: []

    def cast_all(pages = [{_, _} | _]), do: Enum.map(pages, &cast/1)
    def cast_all(metrics), do: [cast({"", metrics})]

    defp cast({title, metrics}), do: %__MODULE__{id: cast_id(title), title: title, metrics: List.wrap(metrics)}

    defp cast_id(title) do
      Base.url_encode64(title, padding: false)
    end
  end

  defmodule Theme do
    @logo """
      <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="currentColor" class="bi bi-symmetry-vertical" viewBox="0 0 16 16">
        <path d="M7 2.5a.5.5 0 0 0-.939-.24l-6 11A.5.5 0 0 0 .5 14h6a.5.5 0 0 0 .5-.5v-11zm2.376-.484a.5.5 0 0 1 .563.245l6 11A.5.5 0 0 1 15.5 14h-6a.5.5 0 0 1-.5-.5v-11a.5.5 0 0 1 .376-.484zM10 4.46V13h4.658L10 4.46z"/>
      </svg>
    """
    @color_palette ~w(
      #3F84E5
      #7EB26D
      #EAB839
      #6ED0E0
      #EF843C
      #E24D42
      #1F78C1
      #BA43A9
      #705DA0
      #508642
      #CCA300
      #447EBC
      #C15C17
      #890F02
      #0A437C
      #6D1F62
      #584477
      #B7DBAB
      #F4D598
      #70DBED
      #F9BA8F
      #F29191
      #82B5D8
      #E5A8E2
      #AEA2E0
      #629E51
      #E5AC0E
      #64B0C8
      #E0752D
      #BF1B00
      #0A50A1
      #962D82
      #614D93
      #9AC48A
      #F2C96D
      #65C5DB
      #F9934E
      #EA6460
      #5195CE
      #D683CE
      #806EB7
      #3F6833
      #967302
      #2F575E
      #99440A
      #58140C
      #052B51
      #511749
      #3F2B5B
      #E0F9D7
      #FCEACA
      #CFFAFF
      #F9E2D2
      #FCE2DE
      #BADFF4
      #F9D9F9
      #DEDAF7
    )

    defstruct header_color: hd(@color_palette), title: "/metrics", logo: @logo, scale: @color_palette
  end

  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  def child_spec(opts),
    do: Supervisor.child_spec(super(opts), id: Keyword.get(opts, :name, __MODULE__))

  @impl Supervisor
  def init(opts) do
    opts[:metrics] || raise ArgumentError, "the :metrics option is required by #{inspect(__MODULE__)}"
    opts[:backend] || raise ArgumentError, "the :backend option is required by #{inspect(__MODULE__)}"

    pages = Page.cast_all(opts[:metrics])

    validate_metrics!(pages)

    metrics =
      pages
      |> Enum.flat_map(& &1.metrics)
      |> Enum.map(&Map.get(&1, :telemetry_metric))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq_by(&{&1.event_name, &1.tags, Event.cast_report_as(&1)})

    State.persist(%{
      backend: opts[:backend],
      theme: struct!(TelemetryUI.Theme, opts[:theme] || %{}),
      pages: pages
    })

    children = [
      {TelemetryUI.WriteBuffer, backend: opts[:backend]},
      {TelemetryUI.Reporter, metrics: metrics},
      {TelemetryUI.Pruner, backend: opts[:backend]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp validate_metrics!(pages) do
    pages
    |> Enum.map(& &1.metrics)
    |> List.flatten()
    |> Enum.each(fn metric ->
      unless TelemetryUI.Web.Component.impl_for(metric) do
        raise TelemetryUI.InvalidMetricWebComponent.exception({metric})
      end
    end)
  end

  def metric_data(metric, filters) do
    TelemetryUI.Scraper.metric(State.get(:backend), metric.telemetry_metric, filters)
  end

  def page_by_id(id), do: Enum.find(pages(), &(&1.id === id))
  def pages, do: State.get(:pages)

  def theme, do: State.get(:theme)

  def metric_by_id(id) do
    pages()
    |> Enum.flat_map(& &1.metrics)
    |> Enum.reject(&is_nil(Map.get(&1, :id)))
    |> Enum.find(&(&1.id === id))
  end
end
