defmodule TelemetryUI.Digest do
  @moduledoc false
  alias TelemetryUI.Digest.InvalidServiceError
  alias TelemetryUI.Digest.InvalidTimeDiffError
  alias TelemetryUI.Digest.Slack

  defprotocol Service do
    @moduledoc false
    def send!(service)
  end

  def send!(args, pages, metric_images, from, to) do
    args
    |> fetch_service(pages, metric_images, from, to)
    |> Service.send!()
  end

  defp fetch_service(%{"slack_hook_url" => url} = args, pages, metric_images, from, to) when is_binary(url) do
    %Slack{url: url, pages: pages, metric_images: metric_images, from: from, to: to, apparence: args["apparence"]}
  end

  defp fetch_service(_args, _pages, _metric_images, _from, _to) do
    raise InvalidServiceError,
      message: """
      You must provide a valid `slack_hook_url` option in your worker args.

       crontab: [
         {"* * * * *", TelemetryUI.Digest.Worker, args: %{slack_hook_url: "https://hook.slack.com/T0000...."}}
       ]
      """
  end

  def cast_time_diff([amount, "day"]) when is_integer(amount), do: {amount, :day}
  def cast_time_diff([amount, "hour"]) when is_integer(amount), do: {amount, :hour}
  def cast_time_diff([amount, "minute"]) when is_integer(amount), do: {amount, :minute}
  def cast_time_diff([amount, "second"]) when is_integer(amount), do: {amount, :second}

  def cast_time_diff(_) do
    raise InvalidTimeDiffError,
      message: """
      Invalid `time_diff` option, must be [integer(), "day" | "hour" | "minute" | "second"]

      crontab: [
        {"* * * * *", TelemetryUI.Digest.Worker, args: %{time_diff: [7, "day"]}}
      ]
      """
  end
end
