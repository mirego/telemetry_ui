defmodule TelemetryUI.Test.Factory do
  @moduledoc false
  use Factori, repo: TelemetryUI.Test.Repo, mappings: [Factori.Mapping.Faker, Factori.Mapping.Enum]
end
