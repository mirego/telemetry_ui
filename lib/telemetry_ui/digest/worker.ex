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

      Digest.send!(args, pages, from, to)

      :ok
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
