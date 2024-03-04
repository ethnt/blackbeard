defmodule Blackbeard.Repo do
  use Ecto.Repo,
    otp_app: :blackbeard,
    adapter: Ecto.Adapters.Postgres
end
