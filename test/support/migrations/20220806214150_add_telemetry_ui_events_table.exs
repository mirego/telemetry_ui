defmodule TelemetryUI.Test.Repo.Migrations.AddTelemetryUIEventsTable do
  @moduledoc false
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  defdelegate up, to: TelemetryUI.Backend.EctoPostgres.Migrations

  def down do
    TelemetryUI.Backend.EctoPostgres.Migrations.down(version: 1)
  end
end
