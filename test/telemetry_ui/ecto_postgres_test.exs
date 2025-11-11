defmodule TelemetryUI.EctoPostgresTest do
  use TelemetryUI.Test.DataCase, async: true

  import Telemetry.Metrics

  alias TelemetryUI.Backend
  alias TelemetryUI.Backend.EctoPostgres.Entry
  alias TelemetryUI.Scraper.Options, as: Options

  def factory_event(metric, attributes \\ []) do
    attributes = Keyword.put_new(attributes, :name, Enum.join(metric.name, "."))
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
      event_name: event.name,
      compare: false
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

    test "conflict min/max", %{backend: backend} do
      Backend.insert_event(backend, 10.0, ~N[2022-02-10T00:00:32], "test", %{}, 2)
      Backend.insert_event(backend, 20.0, ~N[2022-02-10T00:00:33], "test", %{}, 4)

      [event] = backend.repo.all(Entry)

      assert event.value === 15.0
      assert event.min_value === 10.0
      assert event.max_value === 20.0
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

    test "large count overflow protection", %{backend: backend} do
      # Insert with a count near max int4 (2,147,483,647)
      large_count = 2_147_483_640
      Backend.insert_event(backend, 10.0, ~N[2022-02-10T00:00:32], "test", %{}, large_count)

      # This would overflow int4 if not using bigint (2,147,483,640 + 100 > max)
      Backend.insert_event(backend, 20.0, ~N[2022-02-10T00:00:33], "test", %{}, 100)

      [event] = backend.repo.all(Entry)

      # Should not crash and should have the sum
      assert event.count === large_count + 100
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
      event = factory_event(metric, value: 90.0, count: 1, date: ~U[2022-02-10T00:00:30Z])

      options = default_options(event)
      options = %{options | event_name: "some.app.event"}

      [data] = Backend.metric_data(backend, metric, options)

      assert data.value === 90.0
    end

    test "with compare event", %{backend: backend} do
      metric = summary("some.app.event")
      event = factory_event(metric, value: 90.0, count: 1, date: ~U[2022-02-10T00:00:30Z])
      _compare_event = factory_event(metric, value: 30.0, count: 2, date: ~U[2022-02-09T23:45:30Z])

      options = default_options(event)
      options = %{options | event_name: "some.app.event", compare: true}

      [data, compare_data] = Backend.metric_data(backend, metric, options)

      assert data.value === 90.0
      assert data.compare === 0
      assert compare_data.value === 30.0
      assert compare_data.compare === 1
    end

    test "with empty compare event", %{backend: backend} do
      metric = summary("some.app.event")
      event = factory_event(metric, value: 90.0, count: 1, date: ~U[2022-02-10T00:00:30Z])

      options = default_options(event)
      options = %{options | event_name: "some.app.event", compare: true}

      [data, compare_data] = Backend.metric_data(backend, metric, options)

      assert data.value === 90.0
      assert compare_data.value === 0
      assert compare_data.compare === 1
    end

    test "with aggregated event", %{backend: backend} do
      metric = summary("some.app.event")
      event = factory_event(metric, value: 100.0, count: 1, date: ~U[2022-02-10T12:00:30Z])
      factory_event(metric, value: 80.0, count: 2, date: ~U[2022-02-10T11:00:30Z])
      factory_event(metric, value: 80.0, count: 2, date: ~U[2022-02-10T11:00:30Z], tags: %{route: "/"})
      factory_event(metric, value: 10.0, count: 3, date: ~U[2024-02-10T11:00:30Z])

      options = default_options(event, years: -2)
      options = %{options | event_name: "some.app.event"}

      [data] = Backend.metric_data(backend, metric, options)

      assert data.value === 90.0
      assert data.count === 3
      assert data.date === 1_644_451_200_000
    end

    test "with tags", %{backend: backend} do
      metric = summary("some.app.event", tags: [:foo])
      _event = factory_event(metric, value: 90.0, count: 1, date: ~U[2022-02-10T00:00:30Z], tags: %{})
      _event = factory_event(metric, value: 90.0, count: 1, date: ~U[2022-02-10T00:00:30Z], tags: %{"foo" => "bar", "other" => "bar"})
      event = factory_event(metric, value: 90.0, count: 1, date: ~U[2022-02-10T00:00:30Z], tags: %{"foo" => "bar"})

      options = default_options(event)
      options = %{options | event_name: "some.app.event"}

      [data] = Backend.metric_data(backend, metric, options)

      assert data.value === 90.0
      assert data.tags === %{"foo" => "bar"}
    end

    test "with buckets", %{backend: backend} do
      metric = distribution("some.app.event", reporter_options: [buckets: [0, 200, 1000, 5000]])
      event = factory_event(metric, value: 90.0, count: 1, date: ~U[2022-02-10T01:00:00Z])

      options = default_options(event, seconds: -7200)
      options = %{options | event_name: "some.app.event"}

      [data | rest] = Backend.metric_data(backend, metric, options)

      assert Enum.sort(Enum.map(rest, & &1.bucket_start)) === [200.0, 1000.0, 5000.0]
      assert data.bucket_start === 0.0
      assert data.bucket_end === 200.0
      assert data.value === 90.0
    end
  end
end
