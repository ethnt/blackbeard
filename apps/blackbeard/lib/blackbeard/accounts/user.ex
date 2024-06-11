defmodule Blackbeard.Accounts.User do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Blackbeard.Accounts.User

  @type t :: %__MODULE__{
    id: integer(),
    name: String.t() | nil,
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

  @doc """
  Changeset for inviting a user to this instance. Only requires an email, the rest of the attributes will be filled in
  on setup
  """
  @spec invite_changeset(%User{}, map()) :: Ecto.Changeset.t()
  def invite_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_email()
  end

  @spec validate_email(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have an @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, Blackbeard.Repo)
    |> unique_constraint(:email)
  end
end
