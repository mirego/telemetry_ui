if Code.ensure_loaded?(Oban) do
  defmodule TelemetryUI.Digest.Worker do
    use Oban.Worker

    alias TelemetryUI.Digest
    alias TelemetryUI.Web.Filter

    @impl Oban.Worker
    def perform(%Oban.Job{args: args}) do
      {time_amount, time_unit} = Digest.cast_time_diff(args["time_diff"])
      telemetry_name = get_telemetry_name(args)
      share_key = TelemetryUI.theme(telemetry_name).share_key

      if not TelemetryUI.valid_share_key?(share_key) do
        raise Digest.InvalidShareKeyError,
          message: """
          Invalid share_key in your theme. Must be a binary of exactly 16 characters.

          %{
            metrics: ...,
            theme: %{
              share_key: "0123456789123456"
            }
          }
          """
      end

      to = DateTime.utc_now()
      from = DateTime.add(to, -time_amount, time_unit)

      pages =
        args["pages"]
        |> Enum.map(&TelemetryUI.page_by_title(telemetry_name, &1))
        |> Enum.reject(&is_nil/1)
        |> Enum.map(fn page ->
          filters = %Filter{
            page: page.id,
            from: from,
            to: to
          }

          share = Filter.encrypt(filters, args["share_key"])
          {page, args["share_url"] <> "?share=" <> share}
        end)

      Digest.send!(args, pages, from, to)

      :ok
    end

    defp get_telemetry_name(args) do
      if args["telemetry_ui_name"] do
        String.to_existing_atom(args["telemetry_ui_name"])
      else
        :default
      end
    end
  end
end
