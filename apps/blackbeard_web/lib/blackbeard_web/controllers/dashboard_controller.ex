defmodule BlackbeardWeb.DashboardController do
  use BlackbeardWeb, :controller

  def index(conn, _params) do
    conn
    |> render(:index)
  end
end
