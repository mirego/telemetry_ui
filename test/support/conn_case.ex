defmodule TelemetryUI.Test.ConnCase do
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias TelemetryUI.Test.Repo

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest

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
