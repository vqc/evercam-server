defmodule EvercamMedia.Snapshot.SchedulerTest do
  use ExUnit.Case, async: true

  setup do
    schedule = %{
      "Monday" => ["00:00-23:59"], # all day
      "Tuesday" => ["00:00-23:59"],
      "Wednesday" => ["00:00-23:59"],
      "Thursday" => ["00:00-23:59"],
      "Friday" => ["00:00-23:59"],
      "Saturday" => ["00:00-23:59"],
      "Sunday" => ["00:00-23:59"],
    }
   {:ok, schedule: schedule}
 end

 test "scheduler return true at zero hours for all day recording", %{schedule: schedule} do
   all_day_schedule = schedule["Monday"]
   check_time = Calendar.DateTime.from_erl!({{2015, 10, 7}, {00, 59, 59}}, "UTC")
   assert EvercamMedia.Schedule.scheduled?(all_day_schedule, check_time, nil) == {:ok, true}
 end

 test "scheduler return true at 23 hours for all day recording", %{schedule: schedule} do
   all_day_schedule = schedule["Monday"]
   check_time = Calendar.DateTime.from_erl!({{2015, 10, 7}, {23, 59, 00}}, "UTC")
   assert EvercamMedia.Schedule.scheduled?(all_day_schedule, check_time, nil) == {:ok, true}
 end

end
