defmodule TelemetryUI.Test.Repo.Migrations.AddTelemetryUIEventsTable do
  @moduledoc false
  use Ecto.Migration

  alias TelemetryUI.Backend.EctoPostgres.Migrations

  @disable_ddl_transaction true
  @disable_migration_lock true

  defdelegate up, to: Migrations

  def down do
    Migrations.down(version: 1)
  end
end
