defmodule Blackbeard.Accounts do
  @moduledoc false

  alias Blackbeard.Accounts.{User, UserMailer, UserToken}
  alias Blackbeard.Repo

  @doc """
  List users, with optional query parameters
  """
  @spec list_users() :: [User.t()]
  @spec list_users(keyword()) :: [User.t()]
  def list_users(query \\ []) do
    Repo.all(User, query)
  end

  @doc """
  Find a user by their identifier, raising an error if not found
  """
  @spec find_user_by_id!(integer()) :: User.t()
  def find_user_by_id!(id), do: Repo.get!(User, id)

  @doc """
  Finds a user by invite token
  """
  @spec find_user_by_invite_token(UserToken.encoded_token()) :: User.t() | nil
  def find_user_by_invite_token(token) do
    {:ok, query} = UserToken.verify_email_token_query(token, "invite")

    Repo.one(query)
  end

  @doc """
  Sends an invite to a user by creating the user with just an email address, creating an invite token, and sending the
  invite email
  """
  @spec invite_user(map(), (String.t() -> String.t())) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()} | {:error, any()}
  def invite_user(attrs, url_builder) when is_function(url_builder, 1) do
    case Repo.transaction(invite_user_transaction(attrs, url_builder)) do
      {:ok, %{user: %User{}, token: _token, email: %Swoosh.Email{}} = result} ->
        {:ok, result}

      {:error, :user, changeset, _} ->
        {:error, changeset}

      {:error, err} ->
        {:error, err}
    end
  end

  @spec invite_user_transaction(map(), (String.t() -> String.t())) :: Ecto.Multi.t()
  defp invite_user_transaction(attrs, url_builder) when is_function(url_builder, 1) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:user, User.invite_changeset(%User{}, attrs))
    |> Ecto.Multi.run(:token, fn repo, %{user: user} ->
      {token, user_token} = UserToken.build_email_token(user, "invite")

      with {:ok, _} <- repo.insert(user_token) do
        {:ok, token}
      end
    end)
    |> Ecto.Multi.run(:email, fn _repo, %{user: user, token: token} ->
      UserMailer.deliver_invitation_instructions(user, url_builder.(token))
    end)
  end

  @doc """
  Returns changeset for tracking changes to user invite
  """
  @spec invite_user_changeset(%User{}) :: Ecto.Changeset.t()
  @spec invite_user_changeset(%User{}, map()) :: Ecto.Changeset.t()
  def invite_user_changeset(%User{} = user, attrs \\ %{}) do
    User.invite_changeset(user, attrs)
  end

  @doc """
  Sets up a new user given their invite token and the rest of their information (name and password)
  """
  @spec setup_user(UserToken.encoded_token(), map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()} | :error
  def setup_user(invite_token, attrs) do
    case find_user_by_invite_token(invite_token) do
      %User{} = user ->
        case Repo.transaction(setup_user_transaction(user, attrs)) do
          {:ok, %{user: user}} ->
            {:ok, user}

          {:error, :user, %Ecto.Changeset{} = changeset, _} ->
            {:error, changeset}

          _ ->
            :error
        end

      _ ->
        :error
    end
  end

  defp setup_user_transaction(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.setup_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.find_by_user_and_contexts_query(user, ["invite"]))
  end

  @doc """
  Returns a changeset for tracking changes to user setup
  """
  @spec setup_user_changeset(User.t()) :: Ecto.Changeset.t()
  @spec setup_user_changeset(User.t(), map()) :: Ecto.Changeset.t()
  def setup_user_changeset(user, attrs \\ %{}) do
    User.setup_changeset(user, attrs)
  end
end
