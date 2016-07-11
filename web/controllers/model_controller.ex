defmodule EvercamMedia.ModelController do
  use EvercamMedia.Web, :controller
  alias EvercamMedia.ModelView
  import String, only: [to_integer: 1]

  @default_limit 25

  def index(conn, params) do
    with {:ok, vendor} <- vendor_exists(conn, params["vendor_id"])
    do
      limit = get_limit(params["limit"])
      page = get_page(params["page"])

      query =
        VendorModel
        |> VendorModel.check_vendor_in_query(vendor)
        |> VendorModel.check_name_in_query(params["name"])

      total_models = VendorModel.get_models_count(query)
      total_pages = Float.ceil(total_models / limit)

      models =
        query
        |> VendorModel.add_limit_and_offset(limit, page)
        |> VendorModel.get_all
      data = Phoenix.View.render(ModelView, "index.json", %{models: models})
      json(conn, Map.merge(%{pages: total_pages, records: total_models}, data))
    end
  end

  def show(conn, %{"id" => exid}) do
    case VendorModel.by_exid(exid) do
      nil ->
        render_error(conn, 404, "Model Not found.")
      model ->
        conn
        |> render(ModelView, "show.json", %{model: model})
    end
  end

  defp get_limit(limit) when limit in [nil, ""], do: @default_limit
  defp get_limit(limit), do: if to_integer(limit) < 1, do: @default_limit, else: to_integer(limit)

  defp get_page(page) when page in [nil, ""], do: 0
  defp get_page(page), do: if to_integer(page) < 0, do: 0, else: to_integer(page)

  defp vendor_exists(conn, vendor_id) when vendor_id in [nil, ""], do: {:ok, nil}
  defp vendor_exists(conn, vendor_id) do
    case Vendor.by_exid(vendor_id) do
      nil -> render_error(conn, 404, "model vendor not found.")
      %Vendor{} = vendor -> {:ok, vendor}
    end
  end
end
