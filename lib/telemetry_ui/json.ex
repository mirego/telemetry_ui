defmodule TelemetryUI.JSON do
  @moduledoc """
  JSON encoding abstraction layer.

  This module provides a configurable JSON encoder that defaults to:
  - Built-in `JSON` module on Elixir >= 1.18
  - `Jason` library on Elixir < 1.18 (if available)

  ## Configuration

  You can configure a custom JSON encoder in your application config:

      config :telemetry_ui, :json_encoder, MyCustomJSON

  The JSON encoder module must implement an `encode!/1` function.
  """

  @json_encoder Application.compile_env(:telemetry_ui, :json_encoder, :default)

  @encoder (case @json_encoder do
              :default ->
                cond do
                  Code.ensure_loaded?(JSON) and function_exported?(JSON, :encode!, 1) ->
                    JSON

                  Code.ensure_loaded?(Jason) ->
                    Jason

                  true ->
                    nil
                end

              encoder when is_atom(encoder) ->
                encoder
            end)

  if !@encoder do
    raise """
    No JSON encoder available for TelemetryUI.

    TelemetryUI requires a JSON encoder. Please either:
    1. Upgrade to Elixir >= 1.18 (which includes a built-in JSON module)
    2. Add Jason to your dependencies: {:jason, "~> 1.0"}
    3. Configure a custom JSON encoder:

        config :telemetry_ui, :json_encoder, MyCustomJSON
    """
  end

  @doc """
  Encodes the given data structure to JSON.

  Raises if encoding fails.
  """
  @spec encode!(term()) :: String.t()
  def encode!(data) do
    @encoder.encode!(data)
  end

  @doc """
  Returns the configured JSON encoder module.
  """
  @spec encoder() :: module()
  def encoder, do: @encoder
end
