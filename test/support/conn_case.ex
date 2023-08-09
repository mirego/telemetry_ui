defmodule TelemetryUI.Test.ConnCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias TelemetryUI.Test.Repo

  using do
    quote do
      import Phoenix.ConnTest
      # Import conveniences for testing with connections
      import Plug.Conn

      alias TelemetryUI.Test.Factory
      alias TelemetryUI.Test.Repo

      # The default endpoint for testing
      @endpoint TelemetryUI.Test.Endpoint
    end
  end

  setup tags do
    :ok = Sandbox.checkout(Repo)

    unless tags[:async] do
      Sandbox.mode(Repo, {:shared, self()})
    end

    %{conn: Phoenix.ConnTest.build_conn()}
  end
end
