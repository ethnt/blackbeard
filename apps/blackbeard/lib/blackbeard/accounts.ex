defmodule Blackbeard.Accounts do
  @moduledoc false

  alias Blackbeard.Accounts.{User, UserMailer, UserToken}
  alias Blackbeard.Repo

  ### Finders

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
  Find a user by their email
  """
  @spec find_user_by_email(String.t()) :: User.t() | nil
  def find_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Find a user by their email and password (authenticate the user)
  """
  @spec find_user_by_email_and_password(String.t(), String.t()) :: User.t() | nil
  def find_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = find_user_by_email(email)
    if User.valid_password?(user, password), do: user
  end

  ### Sessions

  @doc """
  Find a user by their session token
  """
  @spec find_user_by_session_token(UserToken.token()) :: User.t() | nil
  def find_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)

    Repo.one(query)
  end

  @doc """
  Create and store a user session token
  """
  @spec create_user_session_token(User.t()) :: UserToken.token()
  def create_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Destroy a user session token
  """
  @spec destroy_user_session_token(UserToken.token()) :: :ok
  def destroy_user_session_token(token) do
    Repo.delete_all(UserToken.find_by_token_and_context_query(token, "session"))
    :ok
  end

  ### Invitations

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
  Finds a user by invite token
  """
  @spec find_user_by_invite_token(UserToken.encoded_token()) :: User.t() | nil
  def find_user_by_invite_token(token) do
    {:ok, query} = UserToken.verify_email_token_query(token, "invite")

    Repo.one(query)
  end

  ### Setup (accepting invites)

  @doc """
  Sets up a new user given their invite token and the rest of their information (name and password)
  """
  @spec setup_user(User.t(), map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()} | :error
  def setup_user(user, attrs) do
    case Repo.transaction(setup_user_transaction(user, attrs)) do
      {:ok, %{user: user}} ->
        {:ok, user}

      {:error, :user, %Ecto.Changeset{} = changeset, _} ->
        {:error, changeset}

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

  ### Reset password

  @doc """
  For the submission of the forgot password form. This will always return successfully to hide if an email is in the
  database or not
  """
  @spec forgot_user_password(map(), (String.t() -> String.t())) :: :ok
  def forgot_user_password(%{email: email}, url_builder) do
    case find_user_by_email(email) do
      %User{} = user ->
        deliver_user_reset_password_instructions(user, url_builder)
        :ok

      _ ->
        :ok
    end
  end

  @doc """
  Deliver user reset password instructions
  """
  @spec deliver_user_reset_password_instructions(User.t(), (String.t() -> String.t())) ::
          {:ok, Swoosh.Email.t()} | {:error, any()}
  def deliver_user_reset_password_instructions(%User{} = user, url_builder)
      when is_function(url_builder, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)

    UserMailer.deliver_reset_password_instructions(user, url_builder.(encoded_token))
  end

  @doc """
  Finds a user by a reset password token
  """
  @spec find_user_by_reset_password_token(UserToken.encoded_token()) :: User.t() | nil
  def find_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password") do
      Repo.one(query)
    end
  end

  @doc """
  Resets a user's password and deletes any existing tokens
  """
  @spec reset_user_password(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.update_password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.find_by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Returns a changeset for tracking changes to user password update
  """
  @spec update_user_password_changeset(User.t()) :: Ecto.Changeset.t()
  @spec update_user_password_changeset(User.t(), map()) :: Ecto.Changeset.t()
  def update_user_password_changeset(user, attrs \\ %{}) do
    User.update_password_changeset(user, attrs)
  end

  ### Updating/deleting

  @doc """
  Updates a user's attributes (excluding password)
  """
  @spec update_user(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user(user, attrs) do
    user
    |> User.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns a changeset for tracking changes to user update
  """
  @spec update_user_changeset(User.t()) :: Ecto.Changeset.t()
  @spec update_user_changeset(User.t(), map()) :: Ecto.Changeset.t()
  def update_user_changeset(user, attrs \\ %{}) do
    User.update_changeset(user, attrs)
  end

  @doc """
  Destroys a user
  """
  @spec destroy_user(User.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def destroy_user(user) do
    user
    |> Repo.delete()
  end
end
