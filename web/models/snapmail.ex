defmodule Snapmail do
  use EvercamMedia.Web, :model
  import Ecto.Query
  alias EvercamMedia.Repo

  schema "snapmails" do
    belongs_to :user, User, foreign_key: :user_id
    belongs_to :camera, Camera, foreign_key: :camera_id

    field :exid, :string
    field :subject, :string
    field :recipients, :string
    field :message, :string
    field :notify_days, :string
    field :notify_time, :string
    field :is_public, :boolean, default: false
    timestamps(type: Ecto.DateTime, default: Ecto.DateTime.utc)
  end

  def all do
    Snapmail
    |> preload(:user)
    |> preload(:camera)
    |> preload([camera: :vendor_model])
    |> preload([camera: [vendor_model: :vendor]])
    |> Repo.all
  end

  def by_exid(exid) do
    Snapmail
    |> where(exid: ^String.downcase(exid))
    |> preload(:user)
    |> preload(:camera)
    |> Repo.one
  end

  def get_camera_ids_list(snapmail) do
    snapmail.snapmail_cameras
    |> Enum.map(fn(ar) -> ar.camera.exid end)
    |> Enum.uniq
  end

  def get_days_list(days) when days in [nil, ""], do: []
  def get_days_list(days) do
    days
    |> String.split(",", trim: true)
  end

  def scheduled_now?(days, timezone) do
    today =
      timezone
      |> Calendar.DateTime.now!
      |> Calendar.Date.day_of_week_name
    has_day =
      days
      |> Enum.filter(fn(day) -> day == today end)
      |> List.first
    case has_day do
      nil -> {:ok, false}
      "" -> {:ok, false}
      _day -> {:ok, true}
    end
  end

  def sleep(notify_time, nil) do
    sleep(notify_time, "UTC")
  end
  def sleep(notify_time, timezone) do
    [hours, minutes] = String.split notify_time, ":"
    {h, _} = Integer.parse(hours)
    {m, _} = Integer.parse(minutes)
    current_date =
      Calendar.DateTime.now_utc
      |> Calendar.DateTime.shift_zone!(timezone)

    %{year: year, month: month, day: day} = current_date
    {:ok, notify_date_time} =
      {{year, month, day}, {h, m, 0}}
      |> Calendar.DateTime.from_erl(timezone)
    case Calendar.DateTime.diff(notify_date_time, current_date) do
      {:ok, seconds, _, :after} -> seconds * 1000
      _ -> get_next_day_seconds(h, m, current_date, timezone)
    end
  end

  defp get_next_day_seconds(hours, minutes, current_date, timezone) do
    seconds_of_next_day_alert = (60 * 60 * 24)
    %{year: year, month: month, day: day} = current_date
    notify_date_time =
      {{year, month, day}, {hours, minutes, 0}}
      |> Calendar.DateTime.from_erl(timezone)
      |> elem(1)
      |> Calendar.DateTime.advance!(seconds_of_next_day_alert)

    case Calendar.DateTime.diff(notify_date_time, current_date) do
      {:ok, seconds, _, :after} -> seconds * 1000
      _ -> raise "Seconds Calculate error"
    end
  end
end
