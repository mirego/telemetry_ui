ExUnit.start()
TelemetryUI.Test.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(TelemetryUI.Test.Repo, :manual)

defmodule TelemetryUI.Test.Factory do
  use Factori, repo: TelemetryUI.Test.Repo, mappings: [Factori.Mapping.Faker, Factori.Mapping.Enum]
end

defmodule TelemetryUI.Test.DataCase do
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias TelemetryUI.Test.Repo

  using do
    quote do
      alias TelemetryUI.Test.Factory
      alias TelemetryUI.Test.Repo
    end
  end

  setup tags do
    :ok = Sandbox.checkout(Repo)

    unless tags[:async] do
      Sandbox.mode(Repo, {:shared, self()})
    end

    :ok
  end

  setup_all tags do
    :ok = Sandbox.checkout(Repo)

    unless tags[:async] do
      Sandbox.mode(Repo, {:shared, self()})
    end

    TelemetryUI.Test.Factory.bootstrap()
    :ok
  end
end
