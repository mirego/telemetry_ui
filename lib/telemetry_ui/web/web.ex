defmodule TelemetryUI.Web do
  use Plug.Builder

  alias Ecto.Changeset

  plug(:ensure_allowed)
  plug(:fetch_query_params)
  plug(:fetch_pages)
  plug(:fetch_current_page)
  plug(:index)

  def index(conn = %{params: %{"metric-data" => id}}, _) do
    data =
      case TelemetryUI.metric_by_id(id) do
        metric when is_struct(metric) ->
          case fetch_web_component_metric_data(metric, conn.params) do
            {:ok, data} -> data
            {:async, async} -> async.()
          end

        _ ->
          []
      end

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, Jason.encode!(data))
  end

  def index(conn, _) do
    {filter, params} = fetch_filter_params(%TelemetryUI.Web.Filter{}, conn.params["filter"])

    conn = assign(conn, :filter, Changeset.change(filter))
    conn = assign(conn, :params, params)
    conn = assign(conn, :theme, TelemetryUI.theme())
    conn = assign(conn, :filter_options, TelemetryUI.Scraper.filter_options(params))

    content = Phoenix.HTML.Safe.to_iodata(TelemetryUI.Web.View.render("index.html", Map.put(conn.assigns, :conn, conn)))

    conn
    |> put_resp_header("content-type", "text/html")
    |> send_resp(200, content)
  end

  defp ensure_allowed(conn, _) do
    if conn.assigns[:telemetry_ui_allowed] do
      conn
    else
      halt(send_resp(conn, 404, "Not found"))
    end
  end

  defp fetch_current_page(conn, _) do
    with %{"page" => page_id} when not is_nil(page_id) <- conn.params["filter"],
         page when not is_nil(page) <- TelemetryUI.page_by_id(page_id) do
      page = fetch_metric_data(conn, page)
      assign(conn, :current_page, page)
    else
      _ ->
        assign(conn, :current_page, hd(conn.assigns.pages))
    end
  end

  defp fetch_pages(conn, _) do
    pages = TelemetryUI.pages()
    assign(conn, :pages, pages)
  end

  defp fetch_metric_data(conn, page) do
    metrics =
      Enum.map(page.metrics, fn metric ->
        case fetch_web_component_metric_data(metric, conn.params) do
          {:ok, data} -> %{metric | data: data}
          {:async, _} -> metric
        end
      end)

    %{page | metrics: metrics}
  end

  defp fetch_web_component_metric_data(metric, params) do
    {_filter, params} = fetch_filter_params(%TelemetryUI.Web.Filter{}, params["filter"])
    TelemetryUI.Web.Component.metric_data(metric.web_component, metric, params)
  end

  defp fetch_filter_params(filter, params) do
    filter =
      filter
      |> Changeset.cast(params || %{}, ~w(frame)a)
      |> Changeset.apply_changes()

    params =
      filter
      |> TelemetryUI.Web.Filter.cast_frame_options()
      |> Map.from_struct()

    {filter, params}
  end
end
