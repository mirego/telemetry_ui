defmodule TelemetryUI.Web.Filter do
  @moduledoc false

  use Ecto.Schema

  alias TelemetryUI.Web.Crypto

  @primary_key false
  embedded_schema do
    field(:page, :string)
    field(:from, :utc_datetime)
    field(:to, :utc_datetime)
    field(:frame, :any, virtual: true)
  end

  def frame_options(:custom, theme), do: theme.frame_options
  def frame_options(_frame, theme), do: Enum.reject(theme.frame_options, fn {option, _, _} -> option === :custom end)

  def cast(%{"frame" => "custom"} = params, _) do
    to =
      with to when not is_nil(to) <- params["to"],
           {:ok, datetime, _} <- DateTime.from_iso8601(to) do
        datetime
      else
        _ ->
          nil
      end

    from =
      with from when not is_nil(from) <- params["from"],
           {:ok, datetime, _} <- DateTime.from_iso8601(from) do
        datetime
      else
        _ ->
          nil
      end

    %__MODULE__{from: from, to: to, frame: :custom, page: params["page"]}
  end

  def cast(params, options) do
    {option, duration, unit} = Enum.find(options, fn {name, _, _} -> to_string(name) === params["frame"] end) || Enum.at(options, 1)
    {time_set, time_duration} = fetch_time_frame(unit, duration)

    to =
      DateTime.utc_now()
      |> DateTime.truncate(:second)
      |> DateTime.add(1, :second)

    from =
      to
      |> set_time(time_set)
      |> shift_datetime(time_duration)

    %__MODULE__{from: from, to: to, frame: option, page: params["page"]}
  end

  def encrypt(filters, key) do
    {filters.page, DateTime.to_iso8601(filters.from), DateTime.to_iso8601(filters.to)}
    |> :erlang.term_to_binary(compressed: 9)
    |> Crypto.encrypt(key)
    |> Base.url_encode64(padding: false)
  end

  def decrypt(data, key) do
    with data when is_binary(data) <- Crypto.decrypt(Base.url_decode64!(data, padding: false), key),
         {page, from, to} <- safe_binary_to_term(data),
         {:ok, from, _} <- DateTime.from_iso8601(from),
         {:ok, to, _} <- DateTime.from_iso8601(to) do
      %{
        page: page,
        from: from,
        to: to
      }
    else
      _ -> nil
    end
  rescue
    ArgumentError -> nil
  end

  defp safe_binary_to_term(data) do
    :erlang.binary_to_term(data, [:safe])
  rescue
    ArgumentError -> nil
  end

  defp fetch_time_frame(:second, duration), do: {[second: 0], [seconds: -duration]}
  defp fetch_time_frame(:minute, duration), do: {[second: 0], [minutes: -duration]}
  defp fetch_time_frame(:hour, duration), do: {[second: 0, minute: 0], [hours: -duration]}
  defp fetch_time_frame(:day, duration), do: {[second: 0, minute: 0], [days: -duration]}

  defp fetch_time_frame(:week, duration), do: {[second: 0, minute: 0, hour: 0], [weeks: -duration]}

  defp fetch_time_frame(:month, duration), do: {[second: 0, minute: 0, hour: 0], [months: -duration]}

  defp fetch_time_frame(:year, duration), do: {[second: 0, minute: 0, hour: 0], [years: -duration]}

  defp fetch_time_frame(_, duration), do: fetch_time_frame(:hour, duration)

  defp set_time(datetime, fields) do
    %{year: year, month: month, day: day, hour: hour, minute: minute, second: second} = DateTime.to_naive(datetime)

    second = Keyword.get(fields, :second, second)
    minute = Keyword.get(fields, :minute, minute)
    hour = Keyword.get(fields, :hour, hour)

    {:ok, naive} = NaiveDateTime.new(year, month, day, hour, minute, second)
    DateTime.from_naive!(naive, "Etc/UTC")
  end

  defp shift_datetime(datetime, shifts) do
    Enum.reduce(shifts, datetime, fn {unit, value}, acc ->
      case unit do
        :years -> DateTime.add(acc, value * 365, :day)
        :months -> DateTime.add(acc, value * 30, :day)
        :weeks -> DateTime.add(acc, value * 7, :day)
        :days -> DateTime.add(acc, value, :day)
        :hours -> DateTime.add(acc, value, :hour)
        :minutes -> DateTime.add(acc, value, :minute)
        :seconds -> DateTime.add(acc, value, :second)
        _ -> acc
      end
    end)
  end
end
