defmodule TelemetryUI do
  @moduledoc """
  Main entry point to start all the processes as part of your application.

  # Usage
  ```
  use Application

  def start(_type, _args) do
    children = [
      Shopcast.Repo,
      MyAppWeb.Endpoint,
      {TelemetryUI, my_config()}
    ]
  ```
  The reporter, write buffer and pruner processes will be part of your supervision tree, ensuring that everything runs smoothly.

  The config is a data structure representing all settings used by TelemetryUI.

  ## Config example

  ```
    [
      metrics: [
        {"System", [last_value("vm.memory.total", unit: {:byte, :megabyte})]}
      ],
      theme: %{title: "Metrics"},
      backend: 
        %TelemetryUI.Backend.EctoPostgres{
          repo: MuyApp.Repo,
          pruner_threshold: [months: -1],
          pruner_interval_ms: 3_600_000,
          max_buffer_size: 1_000,
          flush_interval_ms: 10_000
        }
    ]
  ```

  This config will show a basic "last value" chart for the memory usage reported by the VM.
  The title of the page will be "Metrics" and the backend used to store and query metrics will be PostgreSQL.
  See `TelemetryUI.Config` for a list of all options.

  ## Metrics list

  Every kind of metrics exposed by `TelemetryMetrics` is supported by `TelemetryUI`:
  - `last_value`
  - `summary`
  - `sum`
  - `counter`
  - `distribution`

  `TelemetryUI` also exposes its own set of metrics:
  - `average`
  - `average_over_time`
  - `count_over_time`
  - `median`
  - `median_over_time`

  ## The Web
  Finally, when the configuration is done and we actually want to see our metrics, we need to add the `TelemetryUI.Web` module in our router:

  *Phoenix*
  ```
  scope "/" do
    pipe_through([:browser])
    get("/metrics", TelemetryUI.Web, [], [assigns: %{telemetry_ui_allowed: true}])
  end
  ```

  The metrics page is protected by default. It needs to have the `telemetry_ui_allowed` assign to true to render.
  We can imagine having a `:admin_protected` plug that ensure a user is an admin and also assign `telemetry_ui_allowed` to true.

  ```
  scope "/" do
    pipe_through([:browser, :admin_protected])
    get("/metrics", TelemetryUI.Web, [])
  end
  ```

  That’s it! The `/metrics` page will show the metrics as they are recorded. Checkout the Guides to dive into more complex configuration and awesome features :)
  """

  use Supervisor

  defmodule Page do
    @moduledoc false

    defstruct id: nil, title: nil, metrics: [], ui_options: []

    def cast_all([{_, _} | _] = pages), do: Enum.map(pages, &cast/1)
    def cast_all([{_, _, _} | _] = pages), do: Enum.map(pages, &cast/1)
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
    children = [
      {TelemetryUI.Config, config: state, name: config_name(state.name)}
    ]

    children =
      children ++
        if state.backend do
          metrics =
            state.pages
            |> Enum.flat_map(& &1.metrics)
            |> Enum.map(&Map.get(&1, :telemetry_metric))
            |> Enum.reject(&is_nil/1)
            |> Enum.uniq_by(&{&1.name, &1.tags})

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

    children =
      if Application.get_env(:telemetry_ui, :disabled, false) do
        []
      else
        children
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

  def valid_share_key?(share_key), do: is_binary(share_key) and String.length(share_key) <= 15

  def valid_share_url?(url), do: is_binary(URI.parse(url).host)

  def page_by_id(name, id), do: Enum.find(pages(name), &(&1.id === id))
  def page_by_title(name, title), do: Enum.find(pages(name), &(&1.title === title))

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
    if not is_nil(theme.share_key) and not valid_share_key?(theme.share_key) do
      raise TelemetryUI.InvalidThemeShareKeyError.exception(theme.share_key)
    end
  end
end
