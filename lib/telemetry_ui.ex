defmodule TelemetryUI do
  use Supervisor

  defmodule Page do
    @moduledoc false

    defstruct id: nil, title: nil, metrics: [], ui_options: []

    def cast_all(pages = [{_, _} | _]), do: Enum.map(pages, &cast/1)
    def cast_all(pages = [{_, _, _} | _]), do: Enum.map(pages, &cast/1)
    def cast_all(metrics), do: [cast({"", metrics})]

    defp cast({title, metrics}), do: cast({title, metrics, []})

    defp cast({title, metrics, options}) do
      %__MODULE__{
        id: cast_id(title),
        title: title,
        metrics: List.wrap(metrics),
        ui_options: Keyword.get(options, :ui_options, [])
      }
    end

    defp cast_id(title) do
      TelemetryUI.Slug.slugify(title)
    end
  end

  def start_link(opts) do
    opts[:metrics] || raise ArgumentError, "the :metrics option is required by #{inspect(__MODULE__)}"
    pages = Page.cast_all(opts[:metrics])

    name = Keyword.get(opts, :name, :default)
    theme = struct!(TelemetryUI.Theme, opts[:theme] || %{})
    scale = Enum.uniq([theme.primary_color] ++ theme.scale)
    theme = %{theme | scale: scale}

    state = %{
      name: name,
      backend: opts[:backend],
      theme: theme,
      pages: pages
    }

    validate_pages!(state.pages)
    validate_theme!(state.theme)

    Supervisor.start_link(__MODULE__, state, name: Module.concat(__MODULE__, name))
  end

  def child_spec(opts) do
    id = Keyword.get(opts, :name)
    Supervisor.child_spec(super(opts), id: id)
  end

  @impl Supervisor
  def init(state) do
    metrics =
      state.pages
      |> Enum.flat_map(& &1.metrics)
      |> Enum.map(&Map.get(&1, :telemetry_metric))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq_by(&{&1.event_name, &1.tags, TelemetryUI.Event.cast_report_as(&1)})

    children = [
      {TelemetryUI.Config, config: state, name: config_name(state.name)}
    ]

    children =
      children ++
        if state.backend do
          [
            {TelemetryUI.WriteBuffer, backend: state.backend, name: writer_buffer_name(state.name)},
            {TelemetryUI.Reporter, metrics: metrics, write_buffer: writer_buffer_name(state.name)}
          ]
        else
          []
        end

    children =
      children ++
        if state.backend && state.backend.pruner_interval_ms do
          [
            {TelemetryUI.Pruner, backend: state.backend}
          ]
        else
          []
        end

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metric_data(name, metric, filters) do
    TelemetryUI.Scraper.metric(backend(name), metric, filters)
  end

  def insert_metric_data(name, event) do
    TelemetryUI.WriteBuffer.insert(name, event)
  end

  def pages(name), do: config(name, :pages)
  def theme(name), do: config(name, :theme)
  def backend(name), do: config(name, :backend)

  def page_by_id(name, id), do: Enum.find(pages(name), &(&1.id === id))

  def metric_by_id(name, id) do
    name
    |> pages()
    |> Enum.flat_map(& &1.metrics)
    |> Enum.reject(&is_nil(Map.get(&1, :id)))
    |> Enum.find(&(&1.id === id))
  end

  def writer_buffer_name(name), do: Module.concat(TelemetryUI.WriteBuffer, name)
  def config_name(name), do: Module.concat(TelemetryUI.Config, name)

  defp config(name, key), do: GenServer.call(config_name(name), key)

  defp validate_pages!(pages) do
    pages
    |> Enum.flat_map(& &1.metrics)
    |> Enum.each(fn metric ->
      unless TelemetryUI.Web.Component.impl_for(metric) do
        raise TelemetryUI.InvalidMetricWebComponentError.exception({metric})
      end
    end)
  end

  defp validate_theme!(theme) do
    if theme.share_key && String.length(theme.share_key) !== 16 do
      raise TelemetryUI.InvalidThemeShareKeyError.exception(theme.share_key)
    end
  end
end
