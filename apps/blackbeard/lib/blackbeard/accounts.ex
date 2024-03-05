defmodule Blackbeard.Accounts do
  @moduledoc false

  alias Blackbeard.Accounts.User
  alias Blackbeard.Repo

  @doc """
  Find a user by their ID, erroring if not found
  """
  @spec find_user_by_id!(integer()) :: User.t()
  def find_user_by_id!(id), do: Repo.get!(User, id)

  @doc """
  Find a user by their email
  """
  @spec find_user_by_email(String.t()) :: User.t() | nil
  def find_user_by_email(email) when is_binary(email), do: Repo.get_by(User, email: email)
  def find_user_by_email(_), do: nil

  @spec find_user_by_email_and_password(String.t(), String.t()) :: User.t() | nil
  def find_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = find_user_by_email(email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Creates a new, unconfirmed user
  """
  @spec create_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def create_user(attrs) do
    %User{}
    |> User.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns a changeset for tracking changes to user registration
  """
  @spec create_user_changeset(%User{}, map()) :: Ecto.Changeset.t()
  def create_user_changeset(%User{} = user, attrs \\ %{}) do
    User.create_changeset(user, attrs, hash_password: false)
  end
end
