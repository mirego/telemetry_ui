defmodule TelemetryUI.Web do
  use Plug.Builder

  alias Ecto.Changeset

  plug(:fetch_query_params)
  plug(:fetch_shared)
  plug(:assign_default_web_options)
  plug(:assign_filters)
  plug(:assign_share)
  plug(:assign_theme)
  plug(:ensure_allowed)
  plug(:fetch_pages)
  plug(:fetch_current_page)
  plug(:index)

  def index(conn = %{params: %{"metric-data" => id}}, _), do: send_metric_data(conn, id)

  def index(conn, _opts) do
    content = Phoenix.HTML.Safe.to_iodata(TelemetryUI.Web.View.render("index.html", Map.put(conn.assigns, :conn, conn)))

    conn
    |> put_resp_header("content-type", "text/html")
    |> delete_resp_header("content-security-policy")
    |> send_resp(200, content)
  end

  defp send_metric_data(conn, id) do
    data =
      with metric when is_struct(metric) <- TelemetryUI.metric_by_id(id),
           {:async, async} <- fetch_web_component_metric_data(metric, conn.assigns.filters) do
        async.()
      else
        {:ok, data} -> data
        _ -> []
      end

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, Jason.encode!(data))
  end

  defp assign_default_web_options(conn, _) do
    options = List.wrap(Map.get(conn.assigns, :web_options))
    assign(conn, :web_options, options)
  end

  defp assign_filters(conn = %{assigns: %{shared: true}}, _), do: conn

  defp assign_filters(conn, _) do
    {filter_form, filters} = fetch_filters(conn.params["filter"])
    conn = assign(conn, :filters, filters)
    conn = assign(conn, :filter_form, Changeset.change(filter_form))

    conn
  end

  defp assign_theme(conn, _) do
    assign(conn, :theme, TelemetryUI.theme())
  end

  defp assign_share(conn = %{assigns: %{shared: true}}, _), do: conn

  defp assign_share(conn, _) do
    share = generate_share_param(conn.assigns.filters)
    assign(conn, :share, share)
  end

  defp fetch_shared(conn, _) do
    case conn.params["share"] do
      nil ->
        assign(conn, :shared, false)

      share ->
        {:ok, filters} = Plug.Crypto.decrypt(secret_key(), "telemetry_ui", share)
        conn = assign(conn, :filters, filters)
        conn = assign(conn, :filter_form, Changeset.change(%TelemetryUI.Web.Filter{frame: filters.frame}))

        assign(conn, :shared, true)
    end
  end

  defp ensure_allowed(conn = %{assigns: %{shared: true}}, _), do: conn

  defp ensure_allowed(conn, _) do
    if conn.assigns.shared || conn.assigns[:telemetry_ui_allowed] do
      conn
    else
      halt(send_resp(conn, 404, "Not found"))
    end
  end

  defp fetch_current_page(conn = %{assigns: %{shared: true}}, _) do
    page =
      with page_id when not is_nil(page_id) <- conn.assigns.filters.page,
           page when not is_nil(page) <- TelemetryUI.page_by_id(page_id) do
        fetch_metric_data(conn, page)
      else
        _ -> fetch_metric_data(conn, hd(conn.assigns.pages))
      end

    assign(conn, :current_page, page)
  end

  defp fetch_current_page(conn, _) do
    page =
      with %{"page" => page_id} when not is_nil(page_id) <- conn.params["filter"],
           page when not is_nil(page) <- TelemetryUI.page_by_id(page_id) do
        fetch_metric_data(conn, page)
      else
        _ -> fetch_metric_data(conn, hd(conn.assigns.pages))
      end

    assign(conn, :current_page, page)
  end

  defp fetch_pages(conn, _) do
    pages = TelemetryUI.pages()
    assign(conn, :pages, pages)
  end

  defp fetch_metric_data(conn, page) do
    metrics =
      Enum.map(page.metrics, fn metric ->
        case fetch_web_component_metric_data(metric, conn.assigns.filters) do
          {:ok, data} -> %{metric | data: data}
          {:async, _} -> metric
          _ -> metric
        end
      end)

    %{page | metrics: metrics}
  end

  defp fetch_web_component_metric_data(metric, filters) do
    TelemetryUI.Web.Component.metric_data(metric.web_component, metric, filters)
  end

  defp fetch_filters(params) do
    filter_form =
      %TelemetryUI.Web.Filter{}
      |> Changeset.cast(params || %{}, ~w(frame)a)
      |> Changeset.apply_changes()

    filters =
      params
      |> TelemetryUI.Web.Filter.cast()
      |> Map.from_struct()

    {filter_form, filters}
  end

  defp generate_share_param(filters) do
    Plug.Crypto.encrypt(secret_key(), "telemetry_ui", %{filters | frame: :custom})
  end

  defp secret_key(), do: "0b2e0buejobcsobjqsbowobqckbjcsqbjcsbjacs"
end
