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

  @doc """
  Changeset for setting up an invited user
  """
  @spec setup_changeset(User.t(), map()) :: Ecto.Changeset.t()
  def setup_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :password])
    |> validate_required([:name])
    |> validate_password(hash_password: true)
    |> validate_confirmation(:password, message: "does not match password")
  end

  @doc """
  Changeset for updating user attributes (excluding password)
  """
  @spec update_changeset(User.t(), map()) :: Ecto.Changeset.t()
  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email])
    |> validate_required([:name])
    |> validate_email()
  end

  @doc """
  Changeset for updating the password
  """
  @spec update_password_changeset(User.t(), map()) :: Ecto.Changeset.t()
  def update_password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(hash_password: true)
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

  @spec validate_password(Ecto.Changeset.t(), list()) :: Ecto.Changeset.t()
  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    |> maybe_hash_password(opts)
  end

  @spec maybe_hash_password(Ecto.Changeset.t(), list()) :: Ecto.Changeset.t()
  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> validate_length(:password, max: 72, count: :bytes)
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Verifies the password. If there is no user or the user doesn't have a password, we call `Bcrypt.no_user_verify/0` to
  avoid timing attacks
  """
  @spec valid_password?(User.t(), String.t()) :: boolean()
  def valid_password?(%User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
