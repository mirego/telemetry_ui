import Config

alias TelemetryUI.Test.Repo

config :logger, :console, format: "[$level] $message\n"
config :logger, level: :warning

config :phoenix, :json_library, Jason
config :phoenix, :stacktrace_depth, 20

if config_env() in [:dev, :test] do
  config :esbuild,
    version: "0.17.11",
    telemetry_ui: [
      args: ~w(js/app.ts --outdir=../priv/static/assets --bundle),
      cd: Path.expand("../assets", __DIR__),
      env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
    ]

  config :tailwind,
    version: "4.1.14",
    telemetry_ui: [
      args: ~w(--input=css/app.css --output=../priv/static/assets/app.css),
      cd: Path.expand("../assets", __DIR__)
    ]
end

if config_env() in [:test] do
  config :telemetry_ui, Repo,
    priv: "test/support/",
    pool: Ecto.Adapters.SQL.Sandbox,
    url: System.get_env("DATABASE_URL", "postgres://postgres:development@localhost/telemetry_ui_test")

  config :telemetry_ui, TelemetryUI.Test.Endpoint,
    secret_key_base: "Hu4qQN3iKzTV4fJxhorPQlA/osH9fAMtbtjVS58PFgfw3ja5Z18Q/WSNR9wP4OfW",
    render_errors: [view: TelemetryUI.Test.ErrorView]
end

config :telemetry_ui, ecto_repos: [Repo]
