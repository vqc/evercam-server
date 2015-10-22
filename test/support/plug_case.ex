defmodule EvercamMedia.PlugCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  imports other functionalities to make it easier
  to build and query models.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use ExUnit.Case, async: false
      use Plug.Test

      @opts EvercamMedia.Router.init([])
    end
  end

  setup do
    # Wrap this case in a transaction
    Ecto.Adapters.SQL.begin_test_transaction(EvercamMedia.Repo)

    # Roll it back once we are done
    on_exit fn ->
      Ecto.Adapters.SQL.rollback_test_transaction(EvercamMedia.Repo)
    end

    :ok
  end
end
