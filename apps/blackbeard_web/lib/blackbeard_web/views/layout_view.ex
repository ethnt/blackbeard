defmodule BlackbeardWeb.LayoutView do
  use BlackbeardWeb, :view

  @spec title(String.t() | nil) :: String.t()
  def title(page_title) do
    [page_title, "Blackbeard"]
    |> Enum.filter(&(!is_nil(&1)))
    |> Enum.join(" - ")
  end
end
