defmodule TelemetryUI.Web do
  use Plug.Builder

  alias Ecto.Changeset

  plug(:ensure_allowed)
  plug(:fetch_query_params)
  plug(:fetch_pages)
  plug(:fetch_current_page)
  plug(:index)

  def index(conn = %{params: %{"vega-lite-source" => id}}, _) do
    data =
      case TelemetryUI.section_by_id(id) do
        section when is_struct(section, TelemetryUI.Section) ->
          {_filter, params} = fetch_filter_params(%TelemetryUI.Web.Filter{}, conn.params["filter"])

          TelemetryUI.metric_data(section.definition, params)

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
    with page_id when not is_nil(page_id) <- conn.params["page"],
         page when not is_nil(page) <- TelemetryUI.page_by_id(page_id) do
      assign(conn, :current_page, page)
    else
      _ ->
        assign(conn, :current_page, hd(conn.assigns.pages))
    end
  end

  defp fetch_pages(conn, _) do
    assign(conn, :pages, TelemetryUI.pages())
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
