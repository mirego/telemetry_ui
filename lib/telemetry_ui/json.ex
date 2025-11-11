defmodule TelemetryUI.JSON do
  @moduledoc """
  This module provides a configurable JSON library that defaults to:
  - Built-in `JSON` module on Elixir >= 1.18
  - `Jason` library on Elixir < 1.18 (if available)

  ## Configuration

  You can configure a custom JSON library in your application config:

      config :telemetry_ui, :json_library, MyCustomJSON

  The JSON library module must implement an `encode!/1` function and a `decode!/1` function.
  """

  @json_library Application.compile_env(:telemetry_ui, :json_library, :default)

  @library (case @json_library do
              :default ->
                cond do
                  Code.ensure_loaded?(JSON) and function_exported?(JSON, :encode!, 1) ->
                    JSON

                  Code.ensure_loaded?(Jason) ->
                    Jason

                  true ->
                    nil
                end

              library when is_atom(library) ->
                library
            end)

  if !@library do
    raise """
    No JSON library available for TelemetryUI.

    TelemetryUI requires a JSON library. Please either:
    1. Upgrade to Elixir >= 1.18 (which includes a built-in JSON module)
    2. Add Jason to your dependencies: {:jason, "~> 1.0"}
    3. Configure a custom JSON library:

        config :telemetry_ui, :json_library, MyCustomJSON
    """
  end

  @doc """
  Encodes the given data structure to JSON.

  Raises if encoding fails.
  """
  @spec encode!(term()) :: String.t()
  defdelegate encode!(term), to: @library

  @doc """
  Decodes JSON.

  Raises if decoding fails.
  """
  @spec decode!(String.t()) :: term()
  defdelegate decode!(binary), to: @library
end
