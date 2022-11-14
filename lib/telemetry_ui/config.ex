defmodule TelemetryUI.Config do
  @moduledoc false

  use GenServer

  def start_link(initial_state) do
    GenServer.start_link(__MODULE__, initial_state, name: initial_state[:name])
  end

  @impl GenServer
  def init(opts) do
    {:ok, opts[:config]}
  end

  @impl GenServer
  def handle_call(:pages, _, state) do
    {:reply, state.pages, state}
  end

  def handle_call(:theme, _, state) do
    {:reply, state.theme, state}
  end

  def handle_call(:backend, _, state) do
    {:reply, state.backend, state}
  end
end
