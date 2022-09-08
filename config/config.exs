import Config

config :phoenix, :json_library, Jason
config :phoenix, :stacktrace_depth, 20

config :logger, level: :warn
config :logger, :console, format: "[$level] $message\n"

if config_env() === :dev do
  config :tailwind,
    version: "3.1.6",
    default: [
      args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../dist/app.css
      --minify
    ),
      cd: Path.expand("../assets", __DIR__)
    ]

  config :esbuild,
    version: "0.14.41",
    default: [
      args: ~w(js/app.js --bundle --target=es2020 --outdir=../dist --minify),
      cd: Path.expand("../assets", __DIR__),
      env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
    ]
end

config :telemetry_ui, TelemetryUI.Test.Repo,
  name: TelemetryUI.Test.Repo,
  priv: "test/support/",
  pool: Ecto.Adapters.SQL.Sandbox,
  url: "postgres://postgres:development@localhost/telemetry_ui_test"

config :telemetry_ui,
  ecto_repos: [TelemetryUI.Test.Repo]
