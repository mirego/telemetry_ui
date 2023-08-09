defmodule TelemetryUI.VegaLiteToImage do
  @moduledoc false
  if Code.ensure_loaded?(VegaLiteConvert) and Code.ensure_loaded?(Vix.Vips) do
    def enabled?, do: true
  else
    def enabled?, do: false
  end

  if Code.ensure_loaded?(VegaLiteConvert) and Code.ensure_loaded?(Vix.Vips) do
    def export(spec, ".png"), do: png_export(spec)
    def export(_spec, _), do: {:error, "unsupported format"}

    defp png_export(spec) do
      case to_png(spec) do
        {:ok, png} -> {:ok, png, "image/png"}
        error -> error
      end
    end

    defp to_png(spec) do
      with {:ok, svg} <- VegaLiteConvert.to_svg(spec),
           {:ok, {image, _}} <- Vix.Vips.Operation.svgload_buffer(svg) do
        Vix.Vips.Image.write_to_buffer(image, ".png[Q=100]")
      else
        _ -> {:error, "invalid png"}
      end
    end
  else
    def export(_spec, _), do: {:error, "unsupported format"}
  end
end
