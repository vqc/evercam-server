defmodule EvercamMedia.Schedule do
  def scheduled_now?(schedule, timezone) do
    now = Calendar.DateTime.now(timezone)
    scheduled?(schedule, now, timezone)
  end

  def scheduled?(schedule, check_time, timezone \\ nil) do
    check_day = check_time |> Calendar.Date.day_of_week_name
    iterate(schedule[check_day], check_time, timezone)
  end

  defp iterate([head|tail], check_time, timezone) do
    # We expect the head to be in the format "HH:MM-HH:MM"
    head_pattern = ~r/^\d{2}:\d{2}-\d{2}:\d{2}$/
    case Regex.match? head_pattern, head do
      true ->
        [from, to] = String.split head, "-"
        [from_hour, from_minute] = String.split from, ":"
        [to_hour, to_minute] = String.split to, ":"

        check_time_unix_timestamp = check_time |> Calendar.DateTime.Format.unix
        from_unix_timestamp = unix_timestamp(from_hour, from_minute, check_time, timezone)
        to_unix_timestamp = unix_timestamp(to_hour, to_minute, check_time, timezone)

        case between(check_time_unix_timestamp, from_unix_timestamp, to_unix_timestamp) do
          true ->
            {:ok, true}
          _ ->
            iterate(tail, check_time, timezone)
        end
      _ ->
        {:error, "Scheduler got an invalid time format: #{inspect(head)}. Expecting Time in the format HH:MM-HH:MM"}
    end

  end

  defp iterate(nil, check_time, timezone) do
    {:ok, false}
  end

  defp iterate([], check_time,  timezone) do
    {:ok, false}
  end

  defp between(check, start, the_end) do
    check >= start && check <= the_end
  end

  defp unix_timestamp(hours, minutes, date, nil) do
    unix_timestamp(hours, minutes, date, "UTC")
  end

  defp unix_timestamp(hours, minutes, date, timezone) do
    %{year: year, month: month, day: day} = date
    {h, _} = Integer.parse(hours)
    {m, _} = Integer.parse(minutes)
    erl_date_time = {{year, month, day}, {h, m, 0}}
    Calendar.DateTime.from_erl!(erl_date_time, timezone)
    |> Calendar.DateTime.Format.unix
  end
end
