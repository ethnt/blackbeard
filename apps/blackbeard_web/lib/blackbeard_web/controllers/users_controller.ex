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

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"user" => user_params}) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/invite/#{&1}")
          )

        conn
        |> put_flash(:info, "Invited new user")
        |> redirect(~p"/users")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end
