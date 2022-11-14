defmodule TelemetryUI.Test.Factory do
  use Factori, repo: TelemetryUI.Test.Repo, mappings: [Factori.Mapping.Faker, Factori.Mapping.Enum]
end
