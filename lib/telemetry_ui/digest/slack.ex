defmodule TelemetryUI.Digest.Slack do
  @enforce_keys ~w(url pages to from)a
  defstruct url: nil, pages: [], to: nil, from: nil, apparence: nil

  defimpl TelemetryUI.Digest.Service do
    @default_header "Metrics overview"
    @default_icon ":bar_chart:"
    @default_username "TelemetryUI"

    def send!(slack) do
      apparence = slack.apparence || %{}
      header = apparence["header"] || @default_header

      body =
        Map.merge(
          %{
            "username" => @default_username,
            "icon_emoji" => @default_icon,
            "blocks" => [
              %{type: "header", text: %{type: "plain_text", text: header}},
              %{
                type: "context",
                elements: [%{type: "plain_text", text: format_time_frame(slack.from, slack.to)}]
              },
              %{type: "section", text: %{type: "mrkdwn", text: format_pages(slack.pages)}}
            ]
          },
          apparence
        )

      case :httpc.request(:post, {slack.url, [], 'application/json', Jason.encode!(body)}, [], []) do
        {:ok, {{'HTTP/1.1', 200, 'OK'}, _, _}} -> :ok
        {_, error} -> {:error, error}
      end
    end

    defp format_pages(pages), do: Enum.map_join(pages, " ∙ ", fn {page, url} -> "<#{url}|#{page.title}>" end)
    defp format_time_frame(from, to), do: "#{Calendar.strftime(from, "%Y-%m-%d")} - #{Calendar.strftime(to, "%Y-%m-%d")}"
  end
end
