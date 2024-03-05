defmodule BlackbeardWeb.LayoutViewTest do
  @moduledoc false

  use BlackbeardWeb.ConnCase, async: true

  alias BlackbeardWeb.LayoutView

  describe "title/1" do
    test "returns only the site title if no page title is provided" do
      title = LayoutView.title(nil)

      assert title == "Blackbeard"
    end

    test "returns page title and site title divided by bullet if page title is provided" do
      title = LayoutView.title("Foobar")

      assert title == "Foobar • Blackbeard"
    end
  end
end
