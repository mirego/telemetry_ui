defmodule TelemetryUI.WriteBufferTest do
  use TelemetryUI.Test.DataCase, async: true

  import ExUnit.CaptureLog

  alias TelemetryUI.WriteBuffer

  defmodule FakeBackend do
    @moduledoc false
    defstruct max_buffer_size: 1,
              self: nil,
              flush_interval_ms: 10_000,
              insert_date_trunc: "minute",
              verbose: false,
              mock_insert_event: nil

    defimpl TelemetryUI.Backend do
      def insert_event(backend, value, time, event_name, tags, count) do
        if is_function(backend.mock_insert_event, 0) do
          backend.mock_insert_event.()
        else
          send(backend.self, {value, time, event_name, tags, count})
        end
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
    test "when backend insert fails - buffer is cleared" do
      backend = %FakeBackend{
        self: self(),
        max_buffer_size: 1,
        flush_interval_ms: 1,
        mock_insert_event: fn ->
          raise "Database error: too many SQL parameters"
        end
      }

      {:ok, write_buffer} = WriteBuffer.start_link(name: :memory_leak_test, backend: backend)

      write_log =
        capture_log(fn ->
          WriteBuffer.insert(
            write_buffer,
            %TelemetryUI.Event{
              value: 1,
              time: DateTime.utc_now(),
              event_name: "test_event",
              tags: []
            }
          )

          Process.sleep(100)
        end)

      assert :sys.get_state(write_buffer).buffer === []
      assert write_log =~ "Database error: too many SQL parameters"
      assert write_log =~ "Could not insert 1 events"
    end

    test "insert with flush" do
      backend = %FakeBackend{self: self(), max_buffer_size: 100, flush_interval_ms: 400}
      {:ok, write_buffer} = WriteBuffer.start_link(name: :flush_test, backend: backend)

      event = %TelemetryUI.Event{
        value: 1,
        time: DateTime.utc_now(),
        event_name: "test",
        tags: %{}
      }

      WriteBuffer.insert(write_buffer, event)

      assert_receive {1.0, _, "test", %{}, 1}, 1000
    end

    test "insert with buffer size" do
      backend = %FakeBackend{max_buffer_size: 1, self: self()}
      {:ok, write_buffer} = WriteBuffer.start_link(name: :buffer_test, backend: backend)

      event = %TelemetryUI.Event{
        value: 1,
        time: DateTime.utc_now(),
        event_name: "test",
        tags: %{}
      }

      state = :sys.get_state(write_buffer)
      WriteBuffer.handle_cast({:insert, event}, state)

      assert_receive {1.0, _, "test", %{}, 1}
    end

    test "resilient to invalid event" do
      backend = %FakeBackend{max_buffer_size: 3, self: self()}
      {:ok, _write_buffer} = WriteBuffer.start_link(name: :resilient_test, backend: backend)

      buffer = [
        %TelemetryUI.Event{
          value: "invalid",
          time: ~U[2020-01-01T00:00:30Z],
          event_name: "test",
          tags: %{}
        },
        %TelemetryUI.Event{
          value: 1,
          time: ~U[2020-01-01T00:14:12Z],
          event_name: "test_2",
          tags: %{}
        }
      ]

      state = %WriteBuffer.State{buffer: buffer, backend: backend, timer: nil}

      WriteBuffer.handle_info(:tick, state)

      refute_receive {2.0, ~U[2020-01-01T00:00:00Z], "test", %{}, nil}
      assert_receive {1.0, ~U[2020-01-01T00:14:12Z], "test_2", %{}, 1}
    end

    test "cast_value event" do
      backend = %FakeBackend{max_buffer_size: 3, self: self()}
      {:ok, _write_buffer} = WriteBuffer.start_link(name: :cast_value_test, backend: backend)

      cast_value = fn
        "invalid" -> 0
        value -> value
      end

      buffer = [
        %TelemetryUI.Event{
          value: "invalid",
          time: ~U[2020-01-01T00:00:30Z],
          event_name: "test",
          tags: %{},
          cast_value: cast_value
        },
        %TelemetryUI.Event{
          value: 2,
          time: ~U[2020-01-01T00:00:30Z],
          event_name: "test",
          tags: %{},
          cast_value: cast_value
        }
      ]

      state = %WriteBuffer.State{buffer: buffer, backend: backend, timer: nil}

      WriteBuffer.handle_info(:tick, state)

      assert_receive {1.0, ~U[2020-01-01T00:00:30Z], "test", %{}, 2}
    end

    test "group buffer with names" do
      backend = %FakeBackend{max_buffer_size: 3, self: self()}
      {:ok, _write_buffer} = WriteBuffer.start_link(name: :group_buffer_name_test, backend: backend)
      now = DateTime.utc_now()

      buffer = [
        %TelemetryUI.Event{
          value: 2,
          time: now,
          event_name: "test",
          tags: %{}
        },
        %TelemetryUI.Event{
          value: 1,
          time: now,
          event_name: "test2",
          tags: %{}
        }
      ]

      state = %WriteBuffer.State{buffer: buffer, backend: backend, timer: nil}

      event = %TelemetryUI.Event{
        value: 4,
        time: now,
        event_name: "test",
        tags: %{}
      }

      WriteBuffer.handle_cast({:insert, event}, state)

      assert_receive {3.0, _, "test", %{}, 2}
      assert_receive {1.0, _, "test2", %{}, 1}
    end
  end
end
