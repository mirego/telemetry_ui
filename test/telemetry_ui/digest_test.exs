defmodule TelemetryUI.DigestTest do
  use TelemetryUI.Test.DataCase, async: false
  use Mimic

  alias TelemetryUI.Digest

  describe "worker" do
    test "slack with images" do
      args = %{
        "telemetry_ui_name" => "digest_images",
        "time_diff" => [7, "day"],
        "share_url" => "http://localhost:5000/metrics",
        "image_share_url" => "http://localhost:5000/metrics_image_render",
        "pages" => ["Test"],
        "metric_images" => [
          %{"page" => "Test", "description" => "Users count"}
        ],
        "slack_hook_url" => "https://hooks.slack.com/services/T0000000/B00000000/u20000000000",
        "apparence" => %{
          "header" => "Test header",
          "icon_emoji" => ":icon:",
          "username" => "TelemetryUI - Test"
        }
      }

      expect(:httpc, :request, fn :post, {_url, _, _type, body}, [], [] ->
        body = Jason.decode!(body)
        image_block = Enum.find(body["blocks"], &(&1["type"] === "image"))

        assert match?(
                 %{
                   "alt_text" => "Users count",
                   "image_url" => "http://localhost:5000/metrics_image_render/T3Hwd9L68ku?share=" <> _,
                   "title" => %{"text" => "Test - Users count", "type" => "plain_text"},
                   "type" => "image"
                 },
                 image_block
               )

        {:ok, {{'HTTP/1.1', 200, 'OK'}, [], 'ok'}}
      end)

      Digest.Worker.perform(%Oban.Job{args: args})
    end

    test "slack" do
      args = %{
        "telemetry_ui_name" => "digest",
        "time_diff" => [7, "day"],
        "share_url" => "http://localhost:5000/metrics",
        "pages" => ["Test"],
        "slack_hook_url" => "https://hooks.slack.com/services/T0000000/B00000000/u20000000000",
        "apparence" => %{
          "header" => "Test header",
          "icon_emoji" => ":icon:",
          "username" => "TelemetryUI - Test"
        }
      }

      to = DateTime.utc_now()
      from = DateTime.add(to, -7, :day)
      time_frame = "#{Calendar.strftime(from, "%Y-%m-%d")} - #{Calendar.strftime(to, "%Y-%m-%d")}"

      body = %{
        "blocks" => [
          %{
            "text" => %{"text" => "Test header", "type" => "plain_text"},
            "type" => "header"
          },
          %{
            "elements" => [%{"text" => time_frame, "type" => "plain_text"}],
            "type" => "context"
          },
          %{"text" => %{"text" => "", "type" => "mrkdwn"}, "type" => "section"}
        ],
        "header" => "Test header",
        "icon_emoji" => ":icon:",
        "username" => "TelemetryUI - Test"
      }

      request = {args["slack_hook_url"], [], 'application/json', Jason.encode!(body)}

      expect(:httpc, :request, fn :post, ^request, [], [] ->
        {:ok, {{'HTTP/1.1', 200, 'OK'}, [], 'ok'}}
      end)

      Digest.Worker.perform(%Oban.Job{args: args})
    end
  end
end
