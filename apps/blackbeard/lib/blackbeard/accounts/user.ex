defmodule Blackbeard.Accounts.User do
  @moduledoc false

  use Ecto.Schema

  @type t :: %__MODULE__{
    id: integer(),
    name: String.t(),
    email: String.t(),
    password: String.t() | nil,
    hashed_password: String.t() | nil,
    role: :user | :admin | :owner,
    inserted_at: NaiveDateTime.t(),
    updated_at: NaiveDateTime.t()
  }

  schema "users" do
    field :name, :string
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :role, Ecto.Enum, values: [:user, :admin, :owner], default: :user

    timestamps()
  end
end
