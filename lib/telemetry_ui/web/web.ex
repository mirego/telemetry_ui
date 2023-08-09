defmodule TelemetryUI.Web do
  @moduledoc """
  Plug to render an HTML view with all metrics.
  The view handles the different pages in the configurationa and the assets pipeline for CSS and JavaScript.
  The module also handles "async" components data request called in the components.
  """

  use Plug.Builder

  alias Ecto.Changeset
  alias TelemetryUI.Web.Filter
  alias TelemetryUI.Web.View

  plug(:assign_telemetry_name)
  plug(:assign_theme)
  plug(:fetch_query_params)
  plug(:ensure_allowed)
  plug(:assign_filters)
  plug(:fetch_pages)
  plug(:fetch_current_page)
  plug(:assign_share)
  plug(:index)

  def index(%{params: %{"metric-data" => id}} = conn, _) do
    data =
      with metric when is_struct(metric) <- TelemetryUI.metric_by_id(conn.assigns.telemetry_ui_name, id),
           {:async, async} <- fetch_component_metric_data(conn, metric) do
        async.()
      else
        {:ok, data} -> data
        _ -> []
      end

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, Jason.encode!(data))
  end

  def index(conn, _opts) do
    conn = assign(conn, :shared, false)
    content = Phoenix.HTML.Safe.to_iodata(View.render("index.html", Map.put(conn.assigns, :conn, conn)))

    conn
    |> put_resp_header("content-type", "text/html")
    |> delete_resp_header("content-security-policy")
    |> send_resp(200, content)
  end

  defp assign_telemetry_name(conn, _) do
    if conn.assigns[:telemetry_ui_name] do
      conn
    else
      assign(conn, :telemetry_ui_name, :default)
    end
  end

  defp assign_filters(conn, _) do
    params = conn.params["filter"]

    filters =
      params
      |> Filter.cast(conn.assigns.theme.frame_options)
      |> Map.from_struct()

    filter_form =
      %Filter{}
      |> Changeset.cast(filters, ~w(frame)a)
      |> Changeset.apply_changes()

    conn = assign(conn, :filters, filters)
    conn = assign(conn, :filter_form, Changeset.change(filter_form))

    conn
  end

  defp assign_theme(conn, _) do
    assign(conn, :theme, TelemetryUI.theme(conn.assigns.telemetry_ui_name))
  end

  defp assign_share(conn, _) do
    if TelemetryUI.valid_share_key?(conn.assigns.theme.share_key) do
      filters = %{conn.assigns.filters | page: conn.assigns.current_page.id}
      share = Filter.encrypt(filters, conn.assigns.theme.share_key)
      assign(conn, :share, share)
    else
      assign(conn, :share, nil)
    end
  end

  defp ensure_allowed(conn, _) do
    if conn.assigns[:telemetry_ui_allowed] do
      conn
    else
      halt(send_resp(conn, 404, "Not found"))
    end
  end

  defp fetch_current_page(conn, _) do
    page =
      with %{"page" => page_id} when not is_nil(page_id) <- conn.params["filter"],
           page when not is_nil(page) <- TelemetryUI.page_by_id(conn.assigns.telemetry_ui_name, page_id) do
        fetch_metric_data(conn, page)
      else
        _ -> fetch_metric_data(conn, hd(conn.assigns.pages))
      end

    assign(conn, :current_page, page)
  end

  defp fetch_pages(conn, _) do
    pages = TelemetryUI.pages(conn.assigns.telemetry_ui_name)
    assign(conn, :pages, pages)
  end

  defp fetch_metric_data(conn, page) do
    metrics =
      Enum.map(page.metrics, fn metric ->
        case fetch_component_metric_data(conn, metric) do
          {:ok, data} -> %{metric | data: data}
          {:async, _} -> metric
          _ -> metric
        end
      end)

    %{page | metrics: metrics}
  end

  defp fetch_component_metric_data(conn, metric) do
    case Function.info(metric.data_resolver, :arity) do
      {:arity, 0} -> metric.data_resolver.()
      {:arity, 1} -> metric.data_resolver.(conn.assigns.filters)
      {:arity, 2} -> metric.data_resolver.(conn.assigns.telemetry_ui_name, conn.assigns.filters)
    end
  end
end
