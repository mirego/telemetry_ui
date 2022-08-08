defmodule TelemetryUI.Mixfile do
  use Mix.Project

  @version "0.0.1"

  def project do
    [
      app: :telemetry_ui,
      version: @version,
      elixir: "~> 1.13",
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      xref: [exclude: IEx],
      description: "Telemetry based metrics UI",
      deps: deps()
    ]
  end

  def application do
    [mod: []]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.4"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_view, "~> 0.17"},
      {:jason, "~> 1.0"},
      {:ecto, "~> 3.0"},
      {:ecto_sql, "~> 3.0"},
      {:postgrex, "~> 0.16"},
      {:telemetry, "~> 1.0"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:timex, "~> 3.7"},
      {:tailwind, "~> 0.1", only: :dev},
      {:esbuild, "~> 0.5", only: :dev},
      {:phoenix_live_reload, "~> 1.0", only: :dev},

      # Linting
      {:credo, "~> 1.1", only: [:dev, :test]},
      {:credo_envvar, "~> 0.1", only: [:dev, :test], runtime: false},
      {:credo_naming, "~> 1.0", only: [:dev, :test], runtime: false},

      # Docs
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      "assets.compile": ["esbuild default", "tailwind default"]
    ]
  end

  defp package do
    [
      maintainers: ["Simon Prévost"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/mirego/telemetry_ui"},
      files: ~w(dist lib mix.exs README.md)
    ]
  end
end
