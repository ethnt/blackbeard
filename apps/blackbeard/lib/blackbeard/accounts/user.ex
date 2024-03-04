defmodule Blackbeard.Accounts.User do
  @moduledoc false

  use Ecto.Schema

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          email: String.t(),
          password: String.t() | nil,
          hashed_password: String.t(),
          confirmed_at: NaiveDateTime.t() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t() | nil
        }

  schema "users" do
    field :name, :string
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :naive_datetime

    timestamps()
  end
end
