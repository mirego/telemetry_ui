defmodule TelemetryUI.Web do
  use Plug.Builder

  alias Ecto.Changeset

  plug(:ensure_allowed)
  plug(:fetch_query_params)
  plug(:index)

  def index(conn, _) do
    {filter, params} = fetch_filter_params(%TelemetryUI.Web.Filter{}, conn.params["filter"])

    conn = assign(conn, :filter, Changeset.change(filter))
    conn = assign(conn, :params, params)
    conn = assign(conn, :sections, TelemetryUI.sections())
    conn = assign(conn, :theme, TelemetryUI.theme())
    conn = assign(conn, :adapter, TelemetryUI.adapter())

    metrics_data =
      for section <- conn.assigns.sections do
        {section, TelemetryUI.Scraper.metric(section, params, TelemetryUI.adapter())}
      end

    conn = assign(conn, :metrics_data, metrics_data)

    content = Phoenix.HTML.Safe.to_iodata(TelemetryUI.Web.View.render("index.html", conn.assigns))

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
