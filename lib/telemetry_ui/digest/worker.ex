if Code.ensure_loaded?(Oban) do
  defmodule TelemetryUI.Digest.Worker do
    use Oban.Worker

    alias TelemetryUI.Digest
    alias TelemetryUI.Web.Filter

    @impl Oban.Worker
    def perform(%Oban.Job{args: args}) do
      telemetry_name = get_telemetry_name(args)
      share_key = TelemetryUI.theme(telemetry_name).share_key

      if not TelemetryUI.valid_share_key?(share_key) do
        raise TelemetryUI.InvalidThemeShareKeyError.exception(share_key)
      end

      if not TelemetryUI.valid_share_url?(args["share_url"]) do
        raise TelemetryUI.InvalidDigestShareURLError.exception(share_key)
      end

      {time_amount, time_unit} = Digest.cast_time_diff(args["time_diff"])
      to = DateTime.utc_now()
      from = DateTime.add(to, -time_amount, time_unit)
      filters = %Filter{page: nil, to: to, from: from}

      pages = generate_pages_links(args["pages"], telemetry_name, filters, args["share_url"], share_key)
      metric_images = generate_metric_images(args["metric_images"] || [], telemetry_name, filters, args["image_share_url"], share_key)

      Digest.send!(args, pages, metric_images, from, to)

      :ok
    end

    defp generate_metric_images(metric_images, telemetry_name, filters, share_url, share_key) do
      metric_images
      |> Enum.map(fn metric_definition ->
        page = TelemetryUI.page_by_title(telemetry_name, metric_definition["page"])
        metric = Enum.find(page.metrics, fn metric -> metric.title === metric_definition["description"] end)
        {page, metric, metric_definition}
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(fn {page, metric, metric_definition} ->
        filters = %{filters | page: page.id}
        share = Filter.encrypt(filters, share_key)

        params =
          Map.filter(
            %{
              width: metric_definition["width"],
              height: metric_definition["height"],
              id: "#{metric.id}.png",
              share: share
            },
            fn {_, value} -> value not in [nil, ""] end
          )

        {:ok, uri} = URI.new(share_url)
        uri = %{uri | query: URI.encode_query(params)}

        {page, metric, URI.to_string(uri)}
      end)
    end

    defp generate_pages_links(pages, telemetry_name, filters, share_url, share_key) do
      pages
      |> Enum.map(&TelemetryUI.page_by_title(telemetry_name, &1))
      |> Enum.reject(&is_nil/1)
      |> Enum.map(fn page ->
        filters = %{filters | page: page.id}
        share = Filter.encrypt(filters, share_key)
        {page, share_url <> "?share=" <> share}
      end)
    end

    defp get_telemetry_name(args) do
      if args["telemetry_ui_name"],
        do: String.to_existing_atom(args["telemetry_ui_name"]),
        else: :default
    end
  end
end
