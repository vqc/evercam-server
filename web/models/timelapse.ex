defmodule Timelapse do
  use EvercamMedia.Web, :model
  import Ecto.Changeset
  import Ecto.Query
  alias EvercamMedia.Repo

  @required_fields ~w(camera_id title frequency status)
  @optional_fields ~w(exid snapshot_count resolution date_always date_range time_always time_range watermark_logo watermark_position recreate_hls start_recreate_hls last_snapshot_at)

  schema "timelapses" do
    belongs_to :camera, Camera

    field :exid, :string
    field :title, :string
    field :frequency, :integer
    field :snapshot_count, :integer
    field :resolution, :string
    field :status, :integer

    field :date_always, :boolean, default: false
    field :from_date, Ecto.DateTime, default: Ecto.DateTime.utc
    field :time_always, :boolean, default: false
    field :to_date, Ecto.DateTime, default: Ecto.DateTime.utc
    field :watermark_logo, :string
    field :watermark_position, :string
    field :recreate_hls, :boolean, default: false
    field :start_recreate_hls, :boolean, default: false
    field :hls_created, :boolean, default: false
    field :last_snapshot_at, Ecto.DateTime

    timestamps(type: Ecto.DateTime, default: Ecto.DateTime.utc)
  end

  def all do
    Timelapse
    |> preload(:camera)
    |> preload([camera: :owner])
    |> preload([camera: :vendor_model])
    |> preload([camera: [vendor_model: :vendor]])
    |> Repo.all
  end

  def by_camera_id(id) do
    Timelapse
    |> where(camera_id: ^id)
    |> preload(:camera)
    |> Repo.all
  end

  def by_exid(exid) do
    Timelapse
    |> where(exid: ^String.downcase(exid))
    |> preload(:camera)
    |> Repo.one
  end

  def delete_by_exid(exid) do
    Timelapse
    |> where(exid: ^exid)
    |> Repo.delete_all
  end

  defp validate_exid(changeset) do
    case get_field(changeset, :exid) do
      nil -> auto_generate_camera_id(changeset)
      _exid -> changeset |> update_change(:exid, &String.downcase/1)
    end
  end

  def scheduled_now?(timezone, from_date, to_date, date_always, time_always) do
    current_time = Calendar.DateTime.now!(timezone)
    from_date =
      from_date
      |> Ecto.DateTime.to_erl
      |> Calendar.DateTime.from_erl!(timezone)
    to_date =
      to_date
      |> Ecto.DateTime.to_erl
      |> Calendar.DateTime.from_erl!(timezone)

    is_scheduled_now?(timezone, current_time, from_date, to_date, date_always, time_always)
  end

  def is_scheduled_now?(_timezone, _current_time, _from_date, _to_date, true, true), do: {:ok, true}
  def is_scheduled_now?(_timezone, current_time, from_date, to_date, false, false) do
    between?(current_time, from_date, to_date)
  end
  def is_scheduled_now?(timezone, current_time, from_date, to_date, true, false) do
    %{year: current_year, month: current_month, day: current_day} = current_time
    %{hour: from_hour, minute: from_minute} = from_date
    %{hour: to_hour, minute: to_minute} = to_date
    start_date = {{current_year, current_month, current_day}, {from_hour, from_minute, 0}} |> Calendar.DateTime.from_erl(timezone)

    case Calendar.DateTime.diff(from_date, to_date) do
      {:ok, _seconds, _, :after} ->
        %{year: next_year, month: next_month, day: next_day} = current_time |> Calendar.DateTime.advance!(60 * 60 * 24)
        end_date = {{next_year, next_month, next_day}, {to_hour, to_minute, 59}} |> Calendar.DateTime.from_erl(timezone)
        between?(current_time, start_date, end_date)
      _ ->
        end_date = {{current_year, current_month, current_day}, {to_hour, to_minute, 59}} |> Calendar.DateTime.from_erl(timezone)
        between?(current_time, start_date, end_date)
    end
  end
  def is_scheduled_now?(timezone, current_time, from_date, to_date, false, true) do
    %{year: from_year, month: from_month, day: from_day} = from_date
    %{year: to_year, month: to_month, day: to_day} = to_date
    start_date = {{from_year, from_month, from_day}, {0, 0, 0}} |> Calendar.DateTime.from_erl(timezone)
    end_date = {{to_year, to_month, to_day}, {23, 59, 59}} |> Calendar.DateTime.from_erl(timezone)
    between?(current_time, start_date, end_date)
  end

  defp between?(current_time, from_date, to_date) do
    check = current_time |> Calendar.DateTime.Format.unix
    start = from_date |> Calendar.DateTime.Format.unix
    the_end = to_date |> Calendar.DateTime.Format.unix
    case check >= start && check < the_end do
      true ->
        {:ok, true}
      _ ->
        {:ok, false}
    end
  end

  defp auto_generate_camera_id(changeset) do
    case get_field(changeset, :title) do
      nil ->
        changeset
      subject ->
        camera_id =
          subject
          |> String.replace(" ", "")
          |> String.replace("-", "")
          |> String.downcase
          |> String.slice(0..4)
        put_change(changeset, :exid, "#{camera_id}-#{Enum.take_random(?a..?z, 5)}")
    end
  end

  def changeset(model, params \\ :invalid) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> validate_exid
  end
end
