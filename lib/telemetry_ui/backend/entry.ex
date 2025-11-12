defmodule TelemetryUI.Backend.Entry do
  @moduledoc false

  @enforce_keys ~w(name value date)a
  defstruct name: nil,
            value: nil,
            min_value: nil,
            max_value: nil,
            count: 1,
            date: nil,
            tags: %{}
end
