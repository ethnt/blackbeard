defmodule Blackbeard.Accounts do
  @moduledoc false

  alias Blackbeard.Accounts.{User, UserMailer, UserToken}
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

  @doc """
  Find a user by thier email and validate the password (authenticate the user)
  """
  @spec find_user_by_email_and_password(String.t(), String.t()) :: User.t() | nil
  def find_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = find_user_by_email(email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Find a user by their session token
  """
  @spec find_user_by_session_token(UserToken.encoded_token()) :: User.t() | nil
  def find_user_by_session_token(encoded_token) do
    with {:ok, token} <- UserToken.decode_token(encoded_token),
         query <- UserToken.verify_session_token_query(token) do
      Repo.one(query)
    end
  end

  @doc """
  Find a user by their reset password token
  """
  @spec find_user_by_reset_password_token(UserToken.encoded_token()) :: User.t() | nil
  def find_user_by_reset_password_token(encoded_token) do
    with {:ok, token} <- UserToken.decode_token(encoded_token),
         query <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
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

  @doc """
  Updates a user's information that's not their email or password
  """
  @spec update_user(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user(user, attrs) do
    user
    |> User.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns a changeset for tracking changes to user information
  """
  @spec update_user_changeset(User.t(), map()) :: Ecto.Changeset.t()
  def update_user_changeset(user, attrs \\ %{}) do
    User.update_changeset(user, attrs)
  end

  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(update_user_email_transaction(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  @doc """
  Return changeset for updating a user's email
  """
  @spec update_user_email_changeset(User.t(), map()) :: Ecto.Changeset.t()
  def update_user_email_changeset(%User{} = user, attrs \\ %{}) do
    User.update_email_changeset(user, attrs)
  end

  defp update_user_email_transaction(user, email, context) do
    changeset =
      user
      |> User.update_email_changeset(%{email: email})
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.find_by_user_and_context_query(user, [context]))
  end

  @doc """
  Creates a hashed token for use in an update email email
  """
  @spec create_user_update_email_token(User.t(), String.t()) ::
          {:ok, UserToken.encoded_token()} | :error
  def create_user_update_email_token(user, current_email) do
    with {token, user_token} <- UserToken.build_email_token(user, "change:#{current_email}"),
         encoded_token <- UserToken.encode_token(token) do
      case Repo.insert(user_token) do
        {:ok, _} -> {:ok, encoded_token}
        _ -> :error
      end
    end
  end

  @doc """
  Create an update email token and deliver the notification email
  """
  @spec deliver_user_update_email_instructions(User.t(), String.t(), (any() -> any())) ::
          {:ok, Swoosh.Email.t()} | {:error, any()}
  def deliver_user_update_email_instructions(%User{} = user, current_email, url_builder)
      when is_function(url_builder, 1) do
    with {:ok, encoded_token} <- create_user_update_email_token(user, current_email),
         url <- url_builder.(encoded_token) do
      UserMailer.deliver_update_email_instructions(user, url)
    end
  end

  @doc """
  Verifies a user's email update
  """
  @spec verify_user_update_email(User.t(), String.t(), map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def verify_user_update_email(user, password, attrs) do
    user
    |> User.update_email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Update a user's password
  """
  @spec update_user_password(User.t(), String.t(), map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.update_password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.find_by_user_and_context_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Returns a changeset for updating a user's password
  """
  @spec update_user_password_changeset(User.t(), map()) :: Ecto.Changeset.t()
  def update_user_password_changeset(user, attrs \\ %{}) do
    User.update_password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Creates a hashed token for use in a confirmation email. Returns just the encoded token, not the UserToken struct
  """
  @spec create_user_confirmation_token(User.t()) ::
          {:error, :already_confirmed}
          | :error
          | {:ok, UserToken.encoded_token()}
  def create_user_confirmation_token(user) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      with {token, user_token} <- UserToken.build_email_token(user, "confirm"),
           encoded_token <- UserToken.encode_token(token) do
        case Repo.insert(user_token) do
          {:ok, _} -> {:ok, encoded_token}
          _ -> :error
        end
      end
    end
  end

  @doc """
  Create a confirmation token and deliver the user confirmation email
  """
  @spec deliver_user_confirmation_instructions(User.t(), (any() -> any())) ::
          {:ok, Swoosh.Email.t()} | {:error, any()}
  def deliver_user_confirmation_instructions(%User{} = user, url_builder)
      when is_function(url_builder, 1) do
    with {:ok, encoded_token} <- create_user_confirmation_token(user),
         url <- url_builder.(encoded_token) do
      UserMailer.deliver_confirmation_instructions(user, url)
    end
  end

  @doc """
  Confirms a user based on an unhashed token
  """
  @spec confirm_user(UserToken.encoded_token()) :: {:ok, User.t()} | :error
  def confirm_user(encoded_token) do
    with {:ok, token} <- UserToken.decode_token(encoded_token),
         query <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_transaction(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  @spec confirm_user_transaction(User.t()) :: Ecto.Multi.t()
  defp confirm_user_transaction(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.find_by_user_and_context_query(user, ["confirm"]))
  end

  @doc """
  Creates a hashed token for use in a reset password email
  """
  @spec create_user_reset_password_token(User.t()) ::
          {:ok, UserToken.encoded_token()} | {:error, Ecto.Changeset.t()}
  def create_user_reset_password_token(user) do
    with {token, user_token} <- UserToken.build_email_token(user, "reset_password"),
         encoded_token <- UserToken.encode_token(token) do
      case Repo.insert(user_token) do
        {:ok, _} -> {:ok, encoded_token}
        {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
      end
    end
  end

  @doc """
  Create a reset password token and deliver the reset password email
  """
  @spec deliver_user_reset_password_instructions(User.t(), (any() -> any())) ::
          {:ok, Swoosh.Email.t()} | {:error, any()}
  def deliver_user_reset_password_instructions(%User{} = user, url_builder)
      when is_function(url_builder, 1) do
    with {:ok, encoded_token} <- create_user_reset_password_token(user),
         url <- url_builder.(encoded_token) do
      UserMailer.deliver_reset_password_instructions(user, url)
    end
  end

  @doc """
  Reset a user's password. At this point, we've verified their token, so just delete them
  """
  @spec reset_user_password(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.update_password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.find_by_user_and_context_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Creates an unhashed token for use in a session
  """
  @spec create_user_session_token(User.t()) :: {:ok, UserToken.encoded_token()} | :error
  def create_user_session_token(user) do
    with {token, user_token} <- UserToken.build_session_token(user),
         encoded_token <- UserToken.encode_token(token) do
      case Repo.insert(user_token) do
        {:ok, _} -> {:ok, encoded_token}
        _ -> :error
      end
    end
  end

  @doc """
  Delete the given session token
  """
  @spec destroy_session_token(UserToken.encoded_token()) :: :ok | :error
  def destroy_session_token(encoded_token) do
    with {:ok, token} <- UserToken.decode_token(encoded_token) do
      Repo.delete_all(UserToken.find_by_token_and_context_query(token, "session"))
      :ok
    end
  end
end
