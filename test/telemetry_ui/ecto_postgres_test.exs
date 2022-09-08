defmodule TelemetryUI.EctoPostgresTest do
  use TelemetryUI.Test.DataCase

  import Telemetry.Metrics

  alias TelemetryUI.Backend
  alias TelemetryUI.Backend.EctoPostgres.Entry
  alias TelemetryUI.Scraper.Options, as: Options

  def insert_event(metric, attributes \\ []) do
    attributes = Keyword.put_new(attributes, :name, Enum.join(metric.name, "."))
    attributes = Keyword.put_new(attributes, :report_as, "")
    Factory.insert("telemetry_ui_events", attributes)
  end

  def default_options(event \\ %{date: DateTime.utc_now(), name: nil}, shift \\ [seconds: -600]) do
    to =
      event.date
      |> Timex.Timezone.convert("Etc/UTC")
      |> DateTime.truncate(:second)
      |> Timex.shift(seconds: 1)

    from =
      to
      |> Timex.set(second: 0)
      |> Timex.shift(shift)

    %Options{
      from: from,
      to: to,
      event_name: event.name
    }
  end

  setup_all do
    backend = %TelemetryUI.Backend.EctoPostgres{repo: TelemetryUI.Test.Repo}

    [backend: backend]
  end

  describe "insert_event/5 " do
    test "single", %{backend: backend} do
      Backend.insert_event(backend, 90.0, ~N[2022-02-10T00:00:31], "test", %{}, 5)
      [event] = backend.repo.all(Entry)

      assert event.value === 90.0
      assert event.tags === %{}
      assert event.count === 5
      assert event.date === ~U[2022-02-10T00:00:00Z]
    end

    test "conflict", %{backend: backend} do
      Backend.insert_event(backend, 10.0, ~N[2022-02-10T00:00:32], "test", %{}, 2)
      Backend.insert_event(backend, 20.0, ~N[2022-02-10T00:00:33], "test", %{}, 4)

      [event] = backend.repo.all(Entry)

      assert event.value === 15.0
      assert event.tags === %{}
      assert event.count === 6
      assert event.date === ~U[2022-02-10T00:00:00Z]
    end

    test "conflict tags", %{backend: backend} do
      Backend.insert_event(backend, 10.0, ~N[2022-02-10T00:00:32], "test", %{}, 2)
      Backend.insert_event(backend, 20.0, ~N[2022-02-10T00:00:33], "test", %{"foo" => "bar"}, 4)

      events = backend.repo.all(Entry)

      assert Enum.sort(Enum.map(events, & &1.value)) === [10.0, 20.0]
      assert Enum.sort(Enum.map(events, & &1.count)) === [2, 4]
      assert Enum.uniq(Enum.map(events, & &1.date)) === [~U[2022-02-10T00:00:00Z]]
      assert %{} in Enum.map(events, & &1.tags)
      assert %{"foo" => "bar"} in Enum.map(events, & &1.tags)
    end
  end

  describe "metric_data/2 " do
    test "empty data", %{backend: backend} do
      metric = summary("some.app.event")
      options = default_options()
      options = %{options | event_name: "some.app.event"}

      data = Backend.metric_data(backend, metric, options)

      assert Enum.empty?(data)
    end

    test "with event", %{backend: backend} do
      metric = summary("some.app.event")
      event = insert_event(metric, value: 90.0, count: 1, date: ~N[2022-02-10T00:00:30])

      options = default_options(event)
      options = %{options | event_name: "some.app.event"}

      [data] = Backend.metric_data(backend, metric, options)

      assert data.value === 90.0
    end

    test "with tags", %{backend: backend} do
      metric = summary("some.app.event", tags: [:foo])
      _event = insert_event(metric, value: 90.0, count: 1, date: ~N[2022-02-10T00:00:30], tags: %{})
      _event = insert_event(metric, value: 90.0, count: 1, date: ~N[2022-02-10T00:00:30], tags: %{"foo" => "bar", "other" => "bar"})
      event = insert_event(metric, value: 90.0, count: 1, date: ~N[2022-02-10T00:00:30], tags: %{"foo" => "bar"})

      options = default_options(event)
      options = %{options | event_name: "some.app.event"}

      [data] = Backend.metric_data(backend, metric, options)

      assert data.value === 90.0
      assert data.tags === %{"foo" => "bar"}
    end

    test "with compare", %{backend: backend} do
      metric = summary("some.app.event")
      _compare_event = insert_event(metric, value: 20.0, count: 2, date: ~N[2022-02-10T00:00:00])
      event = insert_event(metric, value: 90.0, count: 1, date: ~N[2022-02-10T01:00:00])

      options = default_options(event, seconds: -7200)
      options = %{options | event_name: "some.app.event"}

      [_compare, data] = Backend.metric_data(backend, metric, options)

      assert data.compare_value === 20.0
      assert data.compare_count === 2
      assert data.value === 90.0
      assert data.count === 1
    end
  end
end
