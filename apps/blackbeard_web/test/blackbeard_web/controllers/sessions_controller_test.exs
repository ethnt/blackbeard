defmodule BlackbeardWeb.SessionsControllerTest do
  use BlackbeardWeb.ConnCase, async: true

  setup do
    %{user: insert(:user)}
  end

  describe "GET /login" do
    test "renders the login page", %{conn: conn} do
      conn = get(conn, ~p"/login")

      assert html_response(conn, 200)
    end

    test "redirects if already logged in", %{conn: conn, user: user} do
      conn =
        conn
        |> login_user(user)
        |> get(~p"/login")

      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "POST /login" do
    test "returns an error with invalid credentials", %{conn: conn} do
      conn =
        post(conn, ~p"/login", %{
          "user" => %{"email" => "foo@bar.com", "password" => "no"}
        })

      assert get_flash(conn, :error) == "Invalid email or password"

      response = html_response(conn, 200)
      assert response =~ "Invalid"
    end

    test "logs the user in", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/login", %{
          "user" => %{"email" => user.email, "password" => "blackbeard123"}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == "/"
    end

    test "logs the user in and sets the remember me cookie", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/login", %{
          "user" => %{
            "email" => user.email,
            "password" => "blackbeard123",
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_blackbeard_web_user_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the user in with a return to location", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(user_return_to: "/foo")
        |> post(~p"/login", %{"user" => %{"email" => user.email, "password" => "blackbeard123"}})

      assert redirected_to(conn) == "/foo"
    end
  end

  describe "GET /logout" do
    test "logs the user out", %{conn: conn, user: user} do
      conn =
        conn
        |> login_user(user)
        |> get(~p"/logout")

      assert redirected_to(conn) == ~p"/login"
      refute get_session(conn, :user_token)
    end

    test "works even without a logged in user", %{conn: conn} do
      conn = get(conn, ~p"/logout")

      assert redirected_to(conn) == ~p"/login"
      refute get_session(conn, :user_token)
    end
  end
end
