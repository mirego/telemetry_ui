defmodule TelemetryUI.VegaLiteConvert do
  mix_config = Mix.Project.config()
  version = mix_config[:version]
  github_url = mix_config[:package][:links][:github]
  # Since Rustler 0.27.0, we need to change manually the mode for each env.
  # We want "debug" in dev and test because it's faster to compile.
  mode = if Mix.env() in [:dev, :test], do: :debug, else: :release

  use RustlerPrecompiled,
    otp_app: :telemetry_ui,
    crate: :vegaliteconvert,
    version: version,
    base_url: "#{github_url}/releases/download/v#{version}",
    mode: mode,
    force_build: System.get_env("TELEMETRY_UI_BUILD") in ["1", "true"],
    targets: ~w(
        aarch64-apple-darwin
        aarch64-unknown-linux-gnu
        x86_64-apple-darwin
        x86_64-pc-windows-msvc
        x86_64-unknown-linux-gnu
      )

  def export(spec, extension) do
    case extension do
      ".png" -> png_export(spec)
      _ -> {:error, "unsupported format"}
    end
  end

  defp png_export(spec) do
    case to_png(spec) do
      {:ok, png} -> {:ok, png, "image/png"}
      error -> error
    end
  end

  def to_png(spec) do
    with {:ok, svg} <- to_svg(spec),
         {:ok, {image, _}} <- Vix.Vips.Operation.svgload_buffer(svg) do
      Vix.Vips.Image.write_to_buffer(image, ".png[Q=100]")
    else
      _ -> {:error, "invalid png"}
    end
  end

  def to_svg(_spec), do: :erlang.nif_error(:nif_not_loaded)
end
