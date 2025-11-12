defmodule TelemetryUI.WriteBufferTest do
  use TelemetryUI.Test.DataCase, async: true

  import ExUnit.CaptureLog

  alias TelemetryUI.WriteBuffer

  defmodule FakeBackend do
    @moduledoc false
    defstruct max_buffer_size: 1,
              self: nil,
              flush_interval_ms: 10_000,
              insert_date_bin: nil,
              verbose: false,
              mock_insert_event: nil

    defimpl TelemetryUI.Backend do
      alias TelemetryUI.Backend.Entry

      def insert_event(backend, %Entry{} = entry) do
        if is_function(backend.mock_insert_event, 0) do
          backend.mock_insert_event.()
        else
          send(backend.self, {entry.value, entry.date, entry.name, entry.tags, entry.count, entry.min_value, entry.max_value})
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
      backend = %FakeBackend{self: self(), max_buffer_size: 100, flush_interval_ms: 40}
      {:ok, write_buffer} = WriteBuffer.start_link(name: :flush_test, backend: backend)

      event = %TelemetryUI.Event{
        value: 1,
        time: DateTime.utc_now(),
        event_name: "test",
        tags: %{}
      }

      WriteBuffer.insert(write_buffer, event)

      assert_receive {1.0, _, "test", %{}, 1, 1, 1}, 100
    end

    test "insert with date bin" do
      backend = %FakeBackend{self: self(), max_buffer_size: 2, flush_interval_ms: 1000, insert_date_bin: Duration.new!(minute: 1)}
      {:ok, write_buffer} = WriteBuffer.start_link(name: :flush_test, backend: backend)

      event_one = %TelemetryUI.Event{
        value: 1,
        time: ~U[2020-01-01T00:00:30Z],
        event_name: "test",
        tags: %{}
      }

      event_two = %TelemetryUI.Event{
        value: 1,
        time: ~U[2020-01-01T00:00:50Z],
        event_name: "test",
        tags: %{}
      }

      WriteBuffer.insert(write_buffer, event_one)
      WriteBuffer.insert(write_buffer, event_two)

      assert_receive {1.0, ~U[2020-01-01T00:00:00Z], "test", %{}, 2, 1, 1}, 100
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

      assert_receive {1.0, _, "test", %{}, 1, 1, 1}
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

      refute_receive {2.0, ~U[2020-01-01T00:00:00Z], "test", %{}, nil, _, _}
      assert_receive {1.0, ~U[2020-01-01T00:14:12Z], "test_2", %{}, 1, 1, 1}
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

      assert_receive {1.0, ~U[2020-01-01T00:00:30Z], "test", %{}, 2, 2, "invalid"}
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

      assert_receive {3.0, _, "test", %{}, 2, 2, 4}
      assert_receive {1.0, _, "test2", %{}, 1, 1, 1}
    end
  end

  describe "group by event name and tags with date bin" do
    test "groups events with same name, tags, and within same date bin" do
      backend = %FakeBackend{
        max_buffer_size: 100,
        self: self(),
        flush_interval_ms: 400,
        insert_date_bin: Duration.new!(minute: 1)
      }

      {:ok, _write_buffer} = WriteBuffer.start_link(name: :group_same_bin, backend: backend)

      buffer = [
        %TelemetryUI.Event{
          value: 10,
          time: ~U[2020-01-01T00:00:10Z],
          event_name: "http.request",
          tags: %{method: "GET", path: "/api"}
        },
        %TelemetryUI.Event{
          value: 20,
          time: ~U[2020-01-01T00:00:30Z],
          event_name: "http.request",
          tags: %{method: "GET", path: "/api"}
        },
        %TelemetryUI.Event{
          value: 30,
          time: ~U[2020-01-01T00:00:50Z],
          event_name: "http.request",
          tags: %{method: "GET", path: "/api"}
        }
      ]

      state = %WriteBuffer.State{buffer: buffer, backend: backend, timer: nil}
      WriteBuffer.handle_info(:tick, state)

      assert_receive {20.0, ~U[2020-01-01T00:00:00Z], "http.request", %{method: "GET", path: "/api"}, 3, 10, 30}, 1000
      refute_receive _, 100
    end

    test "separates events across different date bins" do
      backend = %FakeBackend{
        max_buffer_size: 100,
        self: self(),
        flush_interval_ms: 400,
        insert_date_bin: Duration.new!(minute: 1)
      }

      {:ok, _write_buffer} = WriteBuffer.start_link(name: :group_different_bins, backend: backend)

      buffer = [
        %TelemetryUI.Event{
          value: 10,
          time: ~U[2020-01-01T00:00:30Z],
          event_name: "http.request",
          tags: %{method: "GET"}
        },
        %TelemetryUI.Event{
          value: 20,
          time: ~U[2020-01-01T00:01:30Z],
          event_name: "http.request",
          tags: %{method: "GET"}
        },
        %TelemetryUI.Event{
          value: 30,
          time: ~U[2020-01-01T00:02:30Z],
          event_name: "http.request",
          tags: %{method: "GET"}
        }
      ]

      state = %WriteBuffer.State{buffer: buffer, backend: backend, timer: nil}
      WriteBuffer.handle_info(:tick, state)

      assert_receive {10.0, ~U[2020-01-01T00:00:00Z], "http.request", %{method: "GET"}, 1, 10, 10}, 1000
      assert_receive {20.0, ~U[2020-01-01T00:01:00Z], "http.request", %{method: "GET"}, 1, 20, 20}, 1000
      assert_receive {30.0, ~U[2020-01-01T00:02:00Z], "http.request", %{method: "GET"}, 1, 30, 30}, 1000
      refute_receive _, 100
    end

    test "separates events by different event names within same date bin" do
      backend = %FakeBackend{
        max_buffer_size: 100,
        self: self(),
        flush_interval_ms: 400,
        insert_date_bin: Duration.new!(minute: 1)
      }

      {:ok, _write_buffer} = WriteBuffer.start_link(name: :group_different_names, backend: backend)

      buffer = [
        %TelemetryUI.Event{
          value: 10,
          time: ~U[2020-01-01T00:00:10Z],
          event_name: "http.request",
          tags: %{}
        },
        %TelemetryUI.Event{
          value: 20,
          time: ~U[2020-01-01T00:00:30Z],
          event_name: "database.query",
          tags: %{}
        },
        %TelemetryUI.Event{
          value: 30,
          time: ~U[2020-01-01T00:00:50Z],
          event_name: "http.request",
          tags: %{}
        }
      ]

      state = %WriteBuffer.State{buffer: buffer, backend: backend, timer: nil}
      WriteBuffer.handle_info(:tick, state)

      assert_receive {20.0, ~U[2020-01-01T00:00:00Z], "http.request", %{}, 2, 10, 30}, 1000
      assert_receive {20.0, ~U[2020-01-01T00:00:00Z], "database.query", %{}, 1, 20, 20}, 1000
      refute_receive _, 100
    end

    test "separates events by different tags within same date bin and event name" do
      backend = %FakeBackend{
        max_buffer_size: 100,
        self: self(),
        flush_interval_ms: 400,
        insert_date_bin: Duration.new!(minute: 1)
      }

      {:ok, _write_buffer} = WriteBuffer.start_link(name: :group_different_tags, backend: backend)

      buffer = [
        %TelemetryUI.Event{
          value: 10,
          time: ~U[2020-01-01T00:00:10Z],
          event_name: "http.request",
          tags: %{method: "GET"}
        },
        %TelemetryUI.Event{
          value: 20,
          time: ~U[2020-01-01T00:00:30Z],
          event_name: "http.request",
          tags: %{method: "POST"}
        },
        %TelemetryUI.Event{
          value: 30,
          time: ~U[2020-01-01T00:00:50Z],
          event_name: "http.request",
          tags: %{method: "GET"}
        }
      ]

      state = %WriteBuffer.State{buffer: buffer, backend: backend, timer: nil}
      WriteBuffer.handle_info(:tick, state)

      assert_receive {20.0, ~U[2020-01-01T00:00:00Z], "http.request", %{method: "GET"}, 2, 10, 30}, 1000
      assert_receive {20.0, ~U[2020-01-01T00:00:00Z], "http.request", %{method: "POST"}, 1, 20, 20}, 1000
      refute_receive _, 100
    end

    test "groups with 5-minute date bin configuration" do
      backend = %FakeBackend{
        max_buffer_size: 100,
        self: self(),
        flush_interval_ms: 400,
        insert_date_bin: Duration.new!(minute: 5)
      }

      {:ok, _write_buffer} = WriteBuffer.start_link(name: :group_5min_bin, backend: backend)

      buffer = [
        %TelemetryUI.Event{
          value: 10,
          time: ~U[2020-01-01T00:01:00Z],
          event_name: "metric",
          tags: %{}
        },
        %TelemetryUI.Event{
          value: 20,
          time: ~U[2020-01-01T00:03:00Z],
          event_name: "metric",
          tags: %{}
        },
        %TelemetryUI.Event{
          value: 30,
          time: ~U[2020-01-01T00:04:59Z],
          event_name: "metric",
          tags: %{}
        },
        %TelemetryUI.Event{
          value: 40,
          time: ~U[2020-01-01T00:05:01Z],
          event_name: "metric",
          tags: %{}
        }
      ]

      state = %WriteBuffer.State{buffer: buffer, backend: backend, timer: nil}
      WriteBuffer.handle_info(:tick, state)

      assert_receive {20.0, ~U[2020-01-01T00:00:00Z], "metric", %{}, 3, 10, 30}, 1000
      assert_receive {40.0, ~U[2020-01-01T00:05:00Z], "metric", %{}, 1, 40, 40}, 1000
      refute_receive _, 100
    end

    test "groups with 15-minute date bin configuration" do
      backend = %FakeBackend{
        max_buffer_size: 100,
        self: self(),
        flush_interval_ms: 400,
        insert_date_bin: Duration.new!(minute: 15)
      }

      {:ok, _write_buffer} = WriteBuffer.start_link(name: :group_15min_bin, backend: backend)

      buffer = [
        %TelemetryUI.Event{
          value: 5,
          time: ~U[2020-01-01T00:02:00Z],
          event_name: "metric",
          tags: %{env: "prod"}
        },
        %TelemetryUI.Event{
          value: 10,
          time: ~U[2020-01-01T00:08:00Z],
          event_name: "metric",
          tags: %{env: "prod"}
        },
        %TelemetryUI.Event{
          value: 15,
          time: ~U[2020-01-01T00:14:59Z],
          event_name: "metric",
          tags: %{env: "prod"}
        },
        %TelemetryUI.Event{
          value: 20,
          time: ~U[2020-01-01T00:15:01Z],
          event_name: "metric",
          tags: %{env: "prod"}
        }
      ]

      state = %WriteBuffer.State{buffer: buffer, backend: backend, timer: nil}
      WriteBuffer.handle_info(:tick, state)

      assert_receive {10.0, ~U[2020-01-01T00:00:00Z], "metric", %{env: "prod"}, 3, 5, 15}, 1000
      assert_receive {20.0, ~U[2020-01-01T00:15:00Z], "metric", %{env: "prod"}, 1, 20, 20}, 1000
      refute_receive _, 100
    end

    test "complex scenario with multiple event names, tags, and bins" do
      backend = %FakeBackend{
        max_buffer_size: 100,
        self: self(),
        flush_interval_ms: 400,
        insert_date_bin: Duration.new!(minute: 1)
      }

      {:ok, _write_buffer} = WriteBuffer.start_link(name: :group_complex, backend: backend)

      buffer = [
        # Group 1: http.request GET /api at 00:00
        %TelemetryUI.Event{value: 10, time: ~U[2020-01-01T00:00:10Z], event_name: "http.request", tags: %{method: "GET", path: "/api"}},
        %TelemetryUI.Event{value: 20, time: ~U[2020-01-01T00:00:30Z], event_name: "http.request", tags: %{method: "GET", path: "/api"}},
        # Group 2: http.request POST /api at 00:00
        %TelemetryUI.Event{value: 30, time: ~U[2020-01-01T00:00:15Z], event_name: "http.request", tags: %{method: "POST", path: "/api"}},
        # Group 3: database.query at 00:00
        %TelemetryUI.Event{value: 5, time: ~U[2020-01-01T00:00:20Z], event_name: "database.query", tags: %{}},
        %TelemetryUI.Event{value: 15, time: ~U[2020-01-01T00:00:40Z], event_name: "database.query", tags: %{}},
        # Group 4: http.request GET /api at 00:01
        %TelemetryUI.Event{value: 40, time: ~U[2020-01-01T00:01:10Z], event_name: "http.request", tags: %{method: "GET", path: "/api"}},
        # Group 5: http.request GET /users at 00:00
        %TelemetryUI.Event{value: 50, time: ~U[2020-01-01T00:00:50Z], event_name: "http.request", tags: %{method: "GET", path: "/users"}}
      ]

      state = %WriteBuffer.State{buffer: buffer, backend: backend, timer: nil}
      WriteBuffer.handle_info(:tick, state)

      assert_receive {15.0, ~U[2020-01-01T00:00:00Z], "http.request", %{method: "GET", path: "/api"}, 2, 10, 20}, 1000
      assert_receive {30.0, ~U[2020-01-01T00:00:00Z], "http.request", %{method: "POST", path: "/api"}, 1, 30, 30}, 1000
      assert_receive {10.0, ~U[2020-01-01T00:00:00Z], "database.query", %{}, 2, 5, 15}, 1000
      assert_receive {40.0, ~U[2020-01-01T00:01:00Z], "http.request", %{method: "GET", path: "/api"}, 1, 40, 40}, 1000
      assert_receive {50.0, ~U[2020-01-01T00:00:00Z], "http.request", %{method: "GET", path: "/users"}, 1, 50, 50}, 1000
      refute_receive _, 100
    end

    test "grouping without date bin (nil) keeps separate timestamps" do
      backend = %FakeBackend{
        max_buffer_size: 100,
        self: self(),
        flush_interval_ms: 400,
        insert_date_bin: nil
      }

      {:ok, _write_buffer} = WriteBuffer.start_link(name: :group_no_bin, backend: backend)

      time1 = ~U[2020-01-01T00:00:10Z]
      time2 = ~U[2020-01-01T00:00:30Z]

      buffer = [
        %TelemetryUI.Event{
          value: 10,
          time: time1,
          event_name: "metric",
          tags: %{}
        },
        %TelemetryUI.Event{
          value: 20,
          time: time2,
          event_name: "metric",
          tags: %{}
        }
      ]

      state = %WriteBuffer.State{buffer: buffer, backend: backend, timer: nil}
      WriteBuffer.handle_info(:tick, state)

      assert_receive {10.0, ^time1, "metric", %{}, 1, 10, 10}, 1000
      assert_receive {20.0, ^time2, "metric", %{}, 1, 20, 20}, 1000
      refute_receive _, 100
    end
  end

  describe "min/max value tracking" do
    test "tracks min and max values for grouped events" do
      backend = %FakeBackend{
        max_buffer_size: 100,
        self: self(),
        flush_interval_ms: 400,
        insert_date_bin: Duration.new!(minute: 1)
      }

      {:ok, _write_buffer} = WriteBuffer.start_link(name: :min_max_test, backend: backend)

      buffer = [
        %TelemetryUI.Event{
          value: 10,
          time: ~U[2020-01-01T00:00:10Z],
          event_name: "http.request",
          tags: %{method: "GET"}
        },
        %TelemetryUI.Event{
          value: 50,
          time: ~U[2020-01-01T00:00:30Z],
          event_name: "http.request",
          tags: %{method: "GET"}
        },
        %TelemetryUI.Event{
          value: 25,
          time: ~U[2020-01-01T00:00:50Z],
          event_name: "http.request",
          tags: %{method: "GET"}
        }
      ]

      state = %WriteBuffer.State{buffer: buffer, backend: backend, timer: nil}
      WriteBuffer.handle_info(:tick, state)

      # Average should be (10 + 50 + 25) / 3 = 28.333...
      assert_receive {value, ~U[2020-01-01T00:00:00Z], "http.request", %{method: "GET"}, 3, 10, 50}, 1000
      assert_in_delta value, 28.3333, 0.01
      refute_receive _, 100
    end

    test "min and max are same when single event" do
      backend = %FakeBackend{
        max_buffer_size: 100,
        self: self(),
        flush_interval_ms: 400,
        insert_date_bin: Duration.new!(minute: 1)
      }

      {:ok, _write_buffer} = WriteBuffer.start_link(name: :min_max_single, backend: backend)

      buffer = [
        %TelemetryUI.Event{
          value: 42,
          time: ~U[2020-01-01T00:00:10Z],
          event_name: "metric",
          tags: %{}
        }
      ]

      state = %WriteBuffer.State{buffer: buffer, backend: backend, timer: nil}
      WriteBuffer.handle_info(:tick, state)

      assert_receive {42.0, ~U[2020-01-01T00:00:00Z], "metric", %{}, 1, 42, 42}, 1000
      refute_receive _, 100
    end

    test "tracks min/max separately for different groups" do
      backend = %FakeBackend{
        max_buffer_size: 100,
        self: self(),
        flush_interval_ms: 400,
        insert_date_bin: Duration.new!(minute: 1)
      }

      {:ok, _write_buffer} = WriteBuffer.start_link(name: :min_max_groups, backend: backend)

      buffer = [
        # Group 1: GET with values 10, 30, 20
        %TelemetryUI.Event{value: 10, time: ~U[2020-01-01T00:00:10Z], event_name: "http.request", tags: %{method: "GET"}},
        %TelemetryUI.Event{value: 30, time: ~U[2020-01-01T00:00:20Z], event_name: "http.request", tags: %{method: "GET"}},
        %TelemetryUI.Event{value: 20, time: ~U[2020-01-01T00:00:30Z], event_name: "http.request", tags: %{method: "GET"}},
        # Group 2: POST with values 100, 5, 50
        %TelemetryUI.Event{value: 100, time: ~U[2020-01-01T00:00:15Z], event_name: "http.request", tags: %{method: "POST"}},
        %TelemetryUI.Event{value: 5, time: ~U[2020-01-01T00:00:25Z], event_name: "http.request", tags: %{method: "POST"}},
        %TelemetryUI.Event{value: 50, time: ~U[2020-01-01T00:00:35Z], event_name: "http.request", tags: %{method: "POST"}}
      ]

      state = %WriteBuffer.State{buffer: buffer, backend: backend, timer: nil}
      WriteBuffer.handle_info(:tick, state)

      # Group 1: avg=20, min=10, max=30
      assert_receive {20.0, ~U[2020-01-01T00:00:00Z], "http.request", %{method: "GET"}, 3, 10, 30}, 1000
      # Group 2: avg=51.6667, min=5, max=100
      assert_receive {value, ~U[2020-01-01T00:00:00Z], "http.request", %{method: "POST"}, 3, 5, 100}, 1000
      assert_in_delta value, 51.6667, 0.01
      refute_receive _, 100
    end

    test "tracks min/max across different time bins" do
      backend = %FakeBackend{
        max_buffer_size: 100,
        self: self(),
        flush_interval_ms: 400,
        insert_date_bin: Duration.new!(minute: 1)
      }

      {:ok, _write_buffer} = WriteBuffer.start_link(name: :min_max_bins, backend: backend)

      buffer = [
        # Bin 1 (00:00): values 15, 45, 30
        %TelemetryUI.Event{value: 15, time: ~U[2020-01-01T00:00:10Z], event_name: "metric", tags: %{}},
        %TelemetryUI.Event{value: 45, time: ~U[2020-01-01T00:00:30Z], event_name: "metric", tags: %{}},
        %TelemetryUI.Event{value: 30, time: ~U[2020-01-01T00:00:50Z], event_name: "metric", tags: %{}},
        # Bin 2 (00:01): values 5, 95, 50
        %TelemetryUI.Event{value: 5, time: ~U[2020-01-01T00:01:10Z], event_name: "metric", tags: %{}},
        %TelemetryUI.Event{value: 95, time: ~U[2020-01-01T00:01:30Z], event_name: "metric", tags: %{}},
        %TelemetryUI.Event{value: 50, time: ~U[2020-01-01T00:01:50Z], event_name: "metric", tags: %{}}
      ]

      state = %WriteBuffer.State{buffer: buffer, backend: backend, timer: nil}
      WriteBuffer.handle_info(:tick, state)

      # Bin 1: avg=30, min=15, max=45
      assert_receive {30.0, ~U[2020-01-01T00:00:00Z], "metric", %{}, 3, 15, 45}, 1000
      # Bin 2: avg=50, min=5, max=95
      assert_receive {50.0, ~U[2020-01-01T00:01:00Z], "metric", %{}, 3, 5, 95}, 1000
      refute_receive _, 100
    end

    test "handles negative values for min/max" do
      backend = %FakeBackend{
        max_buffer_size: 100,
        self: self(),
        flush_interval_ms: 400,
        insert_date_bin: Duration.new!(minute: 1)
      }

      {:ok, _write_buffer} = WriteBuffer.start_link(name: :min_max_negative, backend: backend)

      buffer = [
        %TelemetryUI.Event{value: -10, time: ~U[2020-01-01T00:00:10Z], event_name: "temperature", tags: %{}},
        %TelemetryUI.Event{value: 5, time: ~U[2020-01-01T00:00:30Z], event_name: "temperature", tags: %{}},
        %TelemetryUI.Event{value: -20, time: ~U[2020-01-01T00:00:50Z], event_name: "temperature", tags: %{}}
      ]

      state = %WriteBuffer.State{buffer: buffer, backend: backend, timer: nil}
      WriteBuffer.handle_info(:tick, state)

      # Average: (-10 + 5 + -20) / 3 = -8.3333
      assert_receive {value, ~U[2020-01-01T00:00:00Z], "temperature", %{}, 3, -20, 5}, 1000
      assert_in_delta value, -8.3333, 0.01
      refute_receive _, 100
    end

    test "handles float values for min/max" do
      backend = %FakeBackend{
        max_buffer_size: 100,
        self: self(),
        flush_interval_ms: 400,
        insert_date_bin: Duration.new!(minute: 1)
      }

      {:ok, _write_buffer} = WriteBuffer.start_link(name: :min_max_float, backend: backend)

      buffer = [
        %TelemetryUI.Event{value: 1.5, time: ~U[2020-01-01T00:00:10Z], event_name: "response_time", tags: %{}},
        %TelemetryUI.Event{value: 3.7, time: ~U[2020-01-01T00:00:30Z], event_name: "response_time", tags: %{}},
        %TelemetryUI.Event{value: 0.2, time: ~U[2020-01-01T00:00:50Z], event_name: "response_time", tags: %{}}
      ]

      state = %WriteBuffer.State{buffer: buffer, backend: backend, timer: nil}
      WriteBuffer.handle_info(:tick, state)

      # Average: (1.5 + 3.7 + 0.2) / 3 = 1.8
      assert_receive {1.8, ~U[2020-01-01T00:00:00Z], "response_time", %{}, 3, 0.2, 3.7}, 1000
      refute_receive _, 100
    end
  end
end
