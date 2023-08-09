defmodule TelemetryUI.Web.Share do
  @moduledoc false
  use Plug.Builder

  alias Ecto.Changeset
  alias TelemetryUI.Web.Filter
  alias TelemetryUI.Web.View

  plug(:assign_telemetry_name)
  plug(:assign_theme)
  plug(:fetch_query_params)
  plug(:fetch_shared)
  plug(:fetch_current_page)
  plug(:index)

  def index(%{params: %{"id" => id} = params} = conn, _opts) do
    metric = fetch_page_metric(conn.assigns.current_page, Path.rootname(id))
    metric = resolve_metric(conn, metric)

    config = fetch_config_from_params(params)

    case View.component_image(conn, metric, Path.extname(id), config) do
      {:ok, data, content_type} ->
        conn
        |> put_resp_header("content-type", content_type)
        |> delete_resp_header("content-security-policy")
        |> send_resp(200, data)

      {:error, error} ->
        send_resp(conn, 400, "Bad request: #{error}")
    end
  end

  def index(conn, _opts) do
    metrics = Enum.map(conn.assigns.current_page.metrics, &resolve_metric(conn, &1))
    conn = assign(conn, :share, conn.params["share"])
    conn = assign(conn, :current_page, %{conn.assigns.current_page | metrics: metrics})

    content = Phoenix.HTML.Safe.to_iodata(View.render("index.html", Map.put(conn.assigns, :conn, conn)))

    conn
    |> put_resp_header("content-type", "text/html")
    |> delete_resp_header("content-security-policy")
    |> send_resp(200, content)
  end

  defp resolve_metric(conn, metric) do
    case fetch_component_metric_data(conn, metric) do
      {:ok, data} -> %{metric | data: data}
      {:async, async} -> %{metric | data: async.()}
      _ -> metric
    end
  end

  defp fetch_config_from_params(params) do
    default_config = [width: 400, height: 100, background: "transparent"]

    integer_config_param = fn value ->
      case is_binary(value) && Integer.parse(value) do
        {integer, _} -> integer
        _ -> nil
      end
    end

    string_config_param = fn value ->
      if value in [nil, ""] do
        nil
      else
        value
      end
    end

    [
      width: integer_config_param.(params["width"]) || default_config[:width],
      height: integer_config_param.(params["height"]) || default_config[:height],
      background: string_config_param.(params["background"]) || default_config[:background]
    ]
  end

  defp assign_telemetry_name(conn, _) do
    if conn.assigns[:telemetry_ui_name] do
      conn
    else
      assign(conn, :telemetry_ui_name, :default)
    end
  end

  defp assign_theme(conn, _) do
    assign(conn, :theme, TelemetryUI.theme(conn.assigns.telemetry_ui_name))
  end

  defp fetch_shared(conn, _) do
    with share when not is_nil(share) <- conn.params["share"],
         secret_key when not is_nil(secret_key) <- conn.assigns.theme.share_key,
         %{} = filters <- Filter.decrypt(share, secret_key) do
      conn = assign(conn, :filters, filters)
      conn = assign(conn, :filter_form, Changeset.change(%Filter{frame: :custom}))

      assign(conn, :shared, true)
    else
      _ ->
        halt(send_resp(conn, 400, "Bad request: invalid share"))
    end
  end

  defp fetch_current_page(conn, _) do
    with page_id when not is_nil(page_id) <- conn.assigns.filters.page,
         page when not is_nil(page) <- TelemetryUI.page_by_id(conn.assigns.telemetry_ui_name, page_id) do
      assign(conn, :current_page, page)
    else
      _ -> halt(send_resp(conn, 404, "Not found"))
    end
  end

  defp fetch_component_metric_data(conn, metric) do
    case Function.info(metric.data_resolver, :arity) do
      {:arity, 0} -> metric.data_resolver.()
      {:arity, 1} -> metric.data_resolver.(conn.assigns.filters)
      {:arity, 2} -> metric.data_resolver.(conn.assigns.telemetry_ui_name, conn.assigns.filters)
    end
  end

  defp fetch_page_metric(page, id) do
    Enum.find(page.metrics, &(&1.id === id))
  end
end
