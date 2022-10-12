defmodule TelemetryUI.Backend.EctoPostgres.Migrations do
  @moduledoc """
  Migrations create and modify the database tables TelemetryUI needs to function.

  ## Usage

  To use migrations in your application you'll need to generate an `Ecto.Migration` that wraps
  calls to `TelemetryUI.Backend.EctoPostgres.Migrations`:

  ```bash
  mix ecto.gen.migration add_telemetry_ui
  ```

  Open the generated migration in your editor and call the `up` and `down` functions on
  `TelemetryUI.Backend.EctoPostgres.Migrations`:

  ```elixir
  defmodule MyApp.Repo.Migrations.AddTelemetryUI do
    use Ecto.Migration

    def up, do: TelemetryUI.Backend.EctoPostgres.Migrations.up()

    def down, do: TelemetryUI.Backend.EctoPostgres.Migrations.down()
  end
  ```

  This will run all of TelemetryUI's versioned migrations for your database.

  Now, run the migration to create the table:

  ```bash
  mix ecto.migrate
  ```

  Migrations between versions are idempotent. As new versions are released, you
  may need to run additional migrations. To do this, generate a new migration:

  ```bash
  mix ecto.gen.migration upgrade_telemetry_ui_to_v11
  ```

  Open the generated migration in your editor and call the `up` and `down`
  functions on `TelemetryUI.Backend.EctoPostgres.Migrations`, passing a version number:

  ```elixir
  defmodule MyApp.Repo.Migrations.UpgradeTelemetryUIToV11 do
    use Ecto.Migration

    def up, do: TelemetryUI.Backend.EctoPostgres.Migrations.up(version: 11)

    def down, do: TelemetryUI.Backend.EctoPostgres.Migrations.down(version: 11)
  end
  ```

  ## Isolation with Prefixes

  TelemetryUI supports namespacing through PostgreSQL schemas, also called "prefixes" in Ecto. With
  prefixes your events table can reside outside of your primary schema (usually public) and you can
  have multiple separate job tables.

  To use a prefix you first have to specify it within your migration:

  ```elixir
  defmodule MyApp.Repo.Migrations.AddPrefixedTelemetryUIJobsTable do
    use Ecto.Migration

    def up, do: TelemetryUI.Backend.EctoPostgres.Migrations.up(prefix: "private")

    def down, do: TelemetryUI.Backend.EctoPostgres.Migrations.down(prefix: "private")
  end
  ```

  The migration will create the "private" schema and all tables, functions and triggers within
  that schema. With the database migrated you'll then specify the prefix in your configuration:

  ```elixir
  config :my_app, TelemetryUI,
    prefix: "private",
    ...
  ```

  In some cases, for example if your "private" schema already exists and your database user in
  production doesn't have permissions to create a new schema, trying to create the schema from the
  migration will result in an error. In such situations, it may be useful to inhibit the creation
  of the "private" schema:

  ```elixir
  defmodule MyApp.Repo.Migrations.AddPrefixedTelemetryUIJobsTable do
    use Ecto.Migration

    def up, do: TelemetryUI.Backend.EctoPostgres.Migrations.up(prefix: "private", create_schema: false)

    def down, do: TelemetryUI.Backend.EctoPostgres.Migrations.down(prefix: "private")
  end
  ```
  """

  use Ecto.Migration

  @initial_version 1
  @current_version 2
  @default_prefix "public"

  @doc """
  Run the `up` changes for all migrations between the initial version and the current version.

  ## Example

  Run all migrations up to the current version:

      TelemetryUI.Backend.EctoPostgres.Migrations.up()

  Run migrations up to a specified version:

      TelemetryUI.Backend.EctoPostgres.Migrations.up(version: 2)

  Run migrations in an alternate prefix:

      TelemetryUI.Backend.EctoPostgres.Migrations.up(prefix: "payments")

  Run migrations in an alternate prefix but don't try to create the schema:

      TelemetryUI.Backend.EctoPostgres.Migrations.up(prefix: "payments", create_schema: false)
  """
  def up(opts \\ []) when is_list(opts) do
    opts = with_defaults(opts, @current_version)
    initial = migrated_version(repo(), opts.prefix)

    cond do
      initial == 0 ->
        change(@initial_version..opts.version, :up, opts)

      initial < opts.version ->
        change((initial + 1)..opts.version, :up, opts)

      true ->
        :ok
    end
  end

  @doc """
  Run the `down` changes for all migrations between the current version and the initial version.

  ## Example

  Run all migrations from current version down to the first:

      TelemetryUI.Backend.EctoPostgres.Migrations.down()

  Run migrations down to and including a specified version:

      TelemetryUI.Backend.EctoPostgres.Migrations.down(version: 5)

  Run migrations in an alternate prefix:

      TelemetryUI.Backend.EctoPostgres.Migrations.down(prefix: "payments")
  """
  def down(opts \\ []) when is_list(opts) do
    opts = with_defaults(opts, @initial_version)
    initial = max(migrated_version(repo(), opts.prefix), @initial_version)

    if initial >= opts.version do
      change(initial..opts.version, :down, opts)
    end
  end

  defp with_defaults(opts, version) do
    opts = Enum.into(opts, %{prefix: @default_prefix, version: version})

    opts
    |> Map.put_new(:create_schema, opts.prefix != @default_prefix)
    |> Map.put_new(:quoted_prefix, inspect(opts.prefix))
    |> Map.put_new(:escaped_prefix, String.replace(opts.prefix, "'", "\\'"))
  end

  @doc false
  def initial_version, do: @initial_version

  @doc false
  def current_version, do: @current_version

  @doc false
  def migrated_version(repo, prefix) do
    escaped_prefix = String.replace(prefix, "'", "\\'")

    query = """
    SELECT description
    FROM pg_class
    LEFT JOIN pg_description ON pg_description.objoid = pg_class.oid
    LEFT JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
    WHERE pg_class.relname = 'telemetry_ui_events'
    AND pg_namespace.nspname = '#{escaped_prefix}'
    """

    case repo.query(query, [], prefix: prefix) do
      {:ok, %{rows: [[version]]}} when is_binary(version) -> String.to_integer(version)
      _ -> 0
    end
  end

  defp change(range, direction, opts) do
    for index <- range do
      pad_idx = String.pad_leading(to_string(index), 2, "0")

      module = Module.concat([__MODULE__, "V#{pad_idx}"])

      case direction do
        :up -> module.up(opts)
        :down -> module.down(opts)
      end
    end

    case direction do
      :up -> record_version(opts, Enum.max(range))
      :down -> record_version(opts, Enum.min(range) - 1)
    end
  end

  defp record_version(_opts, 0), do: :ok

  defp record_version(%{prefix: prefix}, version) do
    execute("COMMENT ON TABLE #{inspect(prefix)}.telemetry_ui_events IS '#{version}'")
  end
end
