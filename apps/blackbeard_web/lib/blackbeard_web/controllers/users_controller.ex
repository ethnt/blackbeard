defmodule BlackbeardWeb.UsersController do
  use BlackbeardWeb, :controller

  alias Blackbeard.Accounts
  alias Blackbeard.Accounts.User

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    users = Accounts.list_users()

    render(conn, "index.html", users: users)
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset = Accounts.create_user_changeset(%User{})
    render(conn, "new.html", changeset: changeset)
  end
end
