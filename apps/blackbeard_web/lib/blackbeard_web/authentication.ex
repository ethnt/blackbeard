defmodule BlackbeardWeb.Authentication do
  @moduledoc false

  import Plug.Conn
  import Phoenix.Controller

  use BlackbeardWeb, :verified_routes

  alias Blackbeard.Accounts

  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_blackbeard_web_user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  @spec login_user(Plug.Conn.t(), Blackbeard.Accounts.User.t(), map()) :: Plug.Conn.t()
  def login_user(conn, user, params \\ %{}) do
    {:ok, encoded_token} = Accounts.create_user_session_token(user)
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_session(:user_token, encoded_token)
    |> maybe_write_remember_me_cookie(encoded_token, params)
    |> redirect(to: user_return_to || "/")
  end

  @spec logout_user(Plug.Conn.t()) :: Plug.Conn.t()
  def logout_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.destroy_session_token(user_token)

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/login")
    |> halt()
  end

  @spec fetch_current_user(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def fetch_current_user(conn, _params) do
    {encoded_token, conn} = ensure_user_token(conn)
    user = encoded_token && Accounts.find_user_by_session_token(encoded_token)
    assign(conn, :current_user, user)
  end

  @spec ensure_user_token(Plug.Conn.t()) ::
          {Accounts.UserToken.encoded_token() | nil, Plug.Conn.t()}
  defp ensure_user_token(conn) do
    if encoded_token = get_session(conn, :user_token) do
      {encoded_token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if encoded_token = conn.cookies[@remember_me_cookie] do
        {encoded_token, put_session(conn, :user_token, encoded_token)}
      else
        {nil, conn}
      end
    end
  end

  @spec renew_session(Plug.Conn.t()) :: Plug.Conn.t()
  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @spec maybe_write_remember_me_cookie(Plug.Conn.t(), Accounts.UserToken.encoded_token(), map()) ::
          Plug.Conn.t()
  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params), do: conn

  @spec require_authenticated_user(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def require_authenticated_user(conn, _params) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> optionally_store_return_to()
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  @spec require_unauthenticated_user(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def require_unauthenticated_user(conn, _params) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: ~p"/")
      |> halt()
    else
      conn
    end
  end

  @spec optionally_store_return_to(Plug.Conn.t()) :: Plug.Conn.t()
  defp optionally_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp optionally_store_return_to(conn), do: conn
end
