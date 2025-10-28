defmodule TelemetryUI.Digest.Slack do
  @moduledoc false
  @enforce_keys ~w(url pages to from metric_images)a
  defstruct url: nil, pages: [], to: nil, from: nil, apparence: nil, metric_images: []

  defimpl TelemetryUI.Digest.Service do
    @default_header "Metrics overview"
    @default_icon ":bar_chart:"
    @default_username "TelemetryUI"

    def send!(slack) do
      apparence = slack.apparence || %{}
      header = apparence["header"] || @default_header

      blocks = [
        %{type: "header", text: %{type: "plain_text", text: header}},
        %{
          type: "context",
          elements: [%{type: "plain_text", text: format_time_frame(slack.from, slack.to)}]
        },
        %{type: "section", text: %{type: "mrkdwn", text: format_pages(slack.pages)}}
      ]

      blocks = maybe_metric_images(blocks, slack.metric_images)

      body =
        Map.merge(
          %{
            "username" => @default_username,
            "icon_emoji" => @default_icon,
            "blocks" => blocks
          },
          apparence
        )

      case :httpc.request(:post, {slack.url, [], ~c"application/json", JSON.encode!(body)}, [], []) do
        {:ok, {{~c"HTTP/1.1", 200, ~c"OK"}, _, _}} -> :ok
        {_, error} -> {:error, error}
      end
    end

    defp maybe_metric_images(blocks, []), do: blocks

    defp maybe_metric_images(blocks, metric_images) do
      image_blocks =
        Enum.map(metric_images, fn {page, metric, url} ->
          %{
            "type" => "image",
            "title" => %{"type" => "plain_text", "text" => page.title <> " - " <> metric.title},
            "image_url" => url,
            "alt_text" => metric.title
          }
        end)

      blocks ++ image_blocks
    end

    defp format_pages(pages), do: Enum.map_join(pages, " ∙ ", fn {page, url} -> "<#{url}|#{page.title}>" end)

    defp format_time_frame(from, to), do: "#{Calendar.strftime(from, "%Y-%m-%d")} - #{Calendar.strftime(to, "%Y-%m-%d")}"
  end
end
