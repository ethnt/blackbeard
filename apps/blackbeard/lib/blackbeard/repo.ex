defmodule Blackbeard.Repo do
  use Ecto.Repo,
    otp_app: :blackbeard,
    adapter: Ecto.Adapters.SQLite3
end
