defmodule BlackbeardWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use BlackbeardWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint BlackbeardWeb.Endpoint

      use BlackbeardWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest, except: [get_flash: 1, get_flash: 2]
      import Blackbeard.Factory
      import BlackbeardWeb.ConnCase
    end
  end

  setup tags do
    Blackbeard.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def login_user(conn, user) do
    {:ok, encoded_token} = Blackbeard.Accounts.create_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, encoded_token)
  end

  @spec get_flash(Plug.Conn.t()) :: struct() | nil
  def get_flash(conn) do
    if flash_map = conn.assigns.flash do
      for {key, val} <- flash_map, into: %{} do
        {String.to_atom(key), val}
      end
    end
  end

  def get_flash(conn, key) do
    get_flash(conn)[key]
  end
end
