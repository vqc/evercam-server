defmodule EvercamMedia.ChangesetView do
  use EvercamMedia.Web, :view

  def render("error.json", %{changeset: changeset}) do
    %{errors: Enum.into(changeset.errors, %{})}
  end

end
