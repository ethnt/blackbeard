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
    |> validate_email(validate_email: true)
  end

  @doc """
  Changeset for setting up an invited user
  """
  @spec setup_changeset(User.t(), map()) :: Ecto.Changeset.t()
  def setup_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :password])
    |> validate_required([:name])
    |> validate_password(hash_password: true)
    |> validate_confirmation(:password)
  end

  @spec validate_email(Ecto.Changeset.t(), keyword()) :: Ecto.Changeset.t()
  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have an @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, Blackbeard.Repo)
    |> maybe_validate_unique_email(opts)
  end

  @spec maybe_validate_unique_email(Ecto.Changeset.t(), keyword()) :: Ecto.Changeset.t()
  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, Blackbeard.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  @spec validate_password(Ecto.Changeset.t(), list()) :: Ecto.Changeset.t()
  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  @spec maybe_hash_password(Ecto.Changeset.t(), list()) :: Ecto.Changeset.t()
  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end
end
