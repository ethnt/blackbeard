defmodule Blackbeard.Accounts.User do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Blackbeard.Accounts.User

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          email: String.t(),
          password: String.t() | nil,
          hashed_password: String.t(),
          role: :user | :admin,
          confirmed_at: NaiveDateTime.t() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t() | nil
        }

  schema "users" do
    field :name, :string
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :role, Ecto.Enum, values: [:user, :admin], default: :user
    field :confirmed_at, :naive_datetime

    timestamps()
  end

  @spec create_changeset(%User{}, map(), hash_password: boolean()) :: Ecto.Changeset.t()
  def create_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:name, :email, :password, :role])
    |> validate_required([:name])
    |> validate_email()
    |> validate_password(opts)
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

  @spec validate_password(Ecto.Changeset.t(), hash_password: boolean()) :: Ecto.Changeset.t()
  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> optionally_hash_password(opts)
  end

  @spec optionally_hash_password(Ecto.Changeset.t(), hash_password: boolean) :: Ecto.Changeset.t()
  defp optionally_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> validate_length(:password, max: 72, count: :bytes)
      |> put_change(:hashed_password, Argon2.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Check a password against a user's hashed password
  """
  @spec valid_password?(User.t(), String.t()) :: boolean()
  def valid_password?(%User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Argon2.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Argon2.no_user_verify()
    false
  end
end
