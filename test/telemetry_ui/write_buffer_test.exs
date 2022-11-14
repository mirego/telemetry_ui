defmodule TelemetryUI.WriteBufferTest do
  use TelemetryUI.Test.DataCase, async: true

  alias TelemetryUI.WriteBuffer

  defmodule FakeBackend do
    defstruct max_buffer_size: 1,
              self: nil,
              flush_interval_ms: 10_000,
              insert_date_trunc: "minute",
              verbose: false

    defimpl TelemetryUI.Backend do
      def insert_event(backend, value, time, event_name, tags, count, report_as) do
        send(backend.self, {value, time, event_name, tags, count, report_as})
      end

      def prune_events!(_backend, _date) do
        :ok
      end

      def metric_data(_backend, _metric, _options) do
        []
      end
    end
  end

  describe "insert/1 " do
    test "insert with flush" do
      backend = %FakeBackend{self: self(), max_buffer_size: 100, flush_interval_ms: 400}
      {:ok, write_buffer} = WriteBuffer.start_link(name: :buffer_test, backend: backend)

      event = %TelemetryUI.Event{
        value: 1,
        time: DateTime.utc_now(),
        event_name: "test",
        tags: %{},
        report_as: nil
      }

      WriteBuffer.insert(write_buffer, event)

      assert_receive {1.0, _, "test", %{}, 1, nil}, 1000
    end

    test "insert with buffer size" do
      backend = %FakeBackend{max_buffer_size: 1, self: self()}
      {:ok, write_buffer} = WriteBuffer.start_link(name: :buffer_test, backend: backend)

      event = %TelemetryUI.Event{
        value: 1,
        time: DateTime.utc_now(),
        event_name: "test",
        tags: %{},
        report_as: nil
      }

      state = :sys.get_state(write_buffer)
      WriteBuffer.handle_cast({:insert, event}, state)

      assert_receive {1.0, _, "test", %{}, 1, nil}
    end

    test "group buffer with time" do
      backend = %FakeBackend{max_buffer_size: 3, self: self()}
      {:ok, _write_buffer} = WriteBuffer.start_link(name: :buffer_test, backend: backend)

      buffer = [
        %TelemetryUI.Event{
          value: 2,
          time: ~U[2020-01-01T00:00:30Z],
          event_name: "test",
          tags: %{},
          report_as: nil
        },
        %TelemetryUI.Event{
          value: 1,
          time: ~U[2020-01-01T00:14:12Z],
          event_name: "test",
          tags: %{},
          report_as: nil
        }
      ]

      state = %WriteBuffer.State{buffer: buffer, backend: backend, timer: nil}

      event = %TelemetryUI.Event{
        value: 4,
        time: ~U[2020-01-01T00:00:33Z],
        event_name: "test",
        tags: %{},
        report_as: nil
      }

      WriteBuffer.handle_cast({:insert, event}, state)

      assert_receive {3.0, ~U[2020-01-01T00:00:00Z], "test", %{}, 2, nil}
      assert_receive {1.0, ~U[2020-01-01T00:14:00Z], "test", %{}, 1, nil}
    end

    test "group buffer with names" do
      backend = %FakeBackend{max_buffer_size: 3, self: self()}
      {:ok, _write_buffer} = WriteBuffer.start_link(name: :buffer_test, backend: backend)
      now = DateTime.utc_now()

      buffer = [
        %TelemetryUI.Event{
          value: 2,
          time: now,
          event_name: "test",
          tags: %{},
          report_as: nil
        },
        %TelemetryUI.Event{
          value: 1,
          time: now,
          event_name: "test2",
          tags: %{},
          report_as: nil
        }
      ]

      state = %WriteBuffer.State{buffer: buffer, backend: backend, timer: nil}

      event = %TelemetryUI.Event{
        value: 4,
        time: now,
        event_name: "test",
        tags: %{},
        report_as: nil
      }

      WriteBuffer.handle_cast({:insert, event}, state)

      assert_receive {3.0, _, "test", %{}, 2, nil}
      assert_receive {1.0, _, "test2", %{}, 1, nil}
    end
  end
end
