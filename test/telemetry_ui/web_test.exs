defmodule TelemetryUI.WebTest do
  use TelemetryUI.Test.ConnCase, async: true

  import Phoenix.ConnTest

  @endpoint TelemetryUI.Test.Endpoint

  def get_html(conn, path) do
    conn |> get(path) |> html_response(200)
  end

  def get_json(conn, path) do
    conn |> get(path) |> json_response(200)
  end

  test "works", %{conn: conn} do
    assert conn |> get("/") |> text_response(200)
  end

  test "empty metrics", %{conn: conn} do
    response = get_html(conn, "/empty-metrics")
    assert response =~ "My test metrics"
  end

  test "data metrics", %{conn: conn} do
    response = get_html(conn, "/data-metrics")
    assert response =~ "My data metrics"
    assert response =~ "Users count"
  end

  test "custom render metrics", %{conn: conn} do
    response = get_html(conn, "/custom-render-metrics")
    assert response =~ "Custom metric in render function"
  end

  test "fetch metric-data", %{conn: conn} do
    [%{metrics: [metric]}] = TelemetryUI.pages(:data_metrics)

    [data] = get_json(conn, "/data-metrics?metric-data=#{metric.id}")
    assert data["count"] === 1
    assert data["value"] === 1.2
    assert {:ok, _, _} = DateTime.from_iso8601(data["date"])
  end
end
