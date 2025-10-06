defmodule TelemetryUI.Mixfile do
  use Mix.Project

  @version "5.1.0"

  def project do
    [
      app: :telemetry_ui,
      version: @version,
      elixir: "~> 1.17",
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      consolidate_protocols: Mix.env() !== :test,
      compilers: Mix.compilers(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      xref: [exclude: IEx],
      description: "Telemetry based metrics UI",
      source_url: "https://github.com/mirego/telemetry_ui",
      homepage_url: "https://github.com/mirego/telemetry_ui",
      docs: [
        extras: ["README.md", "guides/application-data.md", "guides/custom-ui.md", "guides/multi-metrics-endpoints.md"],
        extra_section: "GUIDES",
        groups_for_modules: [
          TelemetryUI: [
            TelemetryUI,
            TelemetryUI.Metrics,
            TelemetryUI.Theme
          ],
          Backend: [
            TelemetryUI.Backend,
            TelemetryUI.Backend.EctoPostgres,
            TelemetryUI.Backend.EctoPostgres.Migrations
          ],
          Web: [
            TelemetryUI.Web,
            TelemetryUI.Web.Share,
            TelemetryUI.Web.Component
          ],
          Reports: [
            TelemetryUI.Digest,
            TelemetryUI.Digest.Slack,
            TelemetryUI.Digest.Worker
          ]
        ],
        main: "readme",
        source_ref: "v#{@version}",
        source_url: "https://github.com/mirego/telemetry_ui"
      ],
      deps: deps()
    ]
  end

  def application do
    [mod: [], extra_applications: [:inets]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.4"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_view, "~> 1.0 or ~> 2.0"},
      {:jason, "~> 1.0"},
      {:ecto, "~> 3.0"},
      {:ecto_sql, "~> 3.0"},
      {:postgrex, "~> 0.16"},
      {:telemetry, "~> 1.0"},
      {:telemetry_metrics, ">= 0.6.0"},
      {:telemetry_poller, "~> 1.0"},
      {:timex, "~> 3.7"},
      {:oban, "~> 2.13", optional: true},

      # Frontend
      {:vega_lite, "~> 0.1"},
      {:phoenix_html, "~> 3.0 or ~> 4.0"},
      {:phoenix_live_view, "~> 0.18 or ~> 1.0"},

      # Images
      {:vega_lite_convert, "~> 1.0"},

      # Asset
      {:tailwind, "~> 0.2", only: [:dev, :test], runtime: false},
      {:esbuild, "~> 0.5", only: [:dev, :test], runtime: false},
      {:phoenix_live_reload, "~> 1.0", only: :dev},

      # Linting
      {:credo, "~> 1.1", only: [:dev, :test]},
      {:credo_envvar, "~> 0.1", only: [:dev, :test], runtime: false},
      {:credo_naming, "~> 2.0", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.0", only: [:dev, :test], runtime: false},

      # Docs
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},

      # Test
      {:factori, ">= 0.0.0", only: :test},
      {:mimic, "~> 2.0", only: :test}
    ]
  end

  defp aliases do
    [
      "assets.setup": [
        "tailwind.install --if-missing",
        "esbuild.install --if-missing",
        "cmd --cd assets npm install"
      ],
      "assets.build": ["esbuild telemetry_ui", "tailwind telemetry_ui"],
      "assets.watch.esbuild": ["esbuild telemetry_ui --watch"],
      "assets.watch.tailwind": ["tailwind telemetry_ui --watch"],
      "assets.deploy": [
        "tailwind telemetry_ui --minify",
        "esbuild telemetry_ui --minify --metafile=meta.json"
      ],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end

  defp package do
    [
      maintainers: ["Simon Prévost"],
      licenses: ["BSD-3-Clause"],
      links: %{github: "https://github.com/mirego/telemetry_ui"},
      files: [
        "lib",
        "priv/static/assets",
        "LICENSE.md",
        "mix.exs",
        "README.md",
        ".formatter.exs"
      ]
    ]
  end
end
