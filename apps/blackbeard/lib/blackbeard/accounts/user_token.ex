defmodule Blackbeard.Accounts.UserToken do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Query

  alias Blackbeard.Accounts.{User, UserToken}

  @hash_algorithm :blake2b
  @rand_size 32

  @reset_password_validity_in_days 1
  @confirm_validity_in_days 7
  @invite_validity_in_days 7
  @session_validity_in_days 60
  @change_email_validity_in_days 7

  @typedoc """
  Represents a Base64 URL-encoded token (in plain text)
  """
  @type encoded_token :: String.t()

  @typedoc """
  Represents a token in the form of a binary blob
  """
  @type token :: binary()

  schema "user_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string

    belongs_to :user, User

    timestamps(updated_at: false)
  end

  @doc """
  Build a token that will be stored in a signed place (session or cookie). No need to hash them in this case
  """
  @spec build_session_token(User.t()) :: {token(), %UserToken{}}
  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)

    {token, %UserToken{token: token, context: "session", user_id: user.id}}
  end

  @doc """
  Generate a token that will be stored in a unsigned place (email). If anyone gets this token, they won't be able to use
  it to gain access. The hashed version is in the database and the unhashed version is sent to the user. When the user
  confirms, they will send the unhashed version -- we will hash their input and match against ours in the database
  """
  @spec build_email_token(User.t(), String.t()) :: {token(), %UserToken{}}
  def build_email_token(%User{email: email} = user, context) do
    build_hashed_token(user, context, email)
  end

  @spec build_hashed_token(User.t(), String.t(), String.t()) :: {token(), %UserToken{}}
  defp build_hashed_token(%User{id: user_id}, context, sent_to) do
    with token <- :crypto.strong_rand_bytes(@rand_size),
         hashed_token <- hash_token(token) do
      {token,
       %UserToken{token: hashed_token, context: context, sent_to: sent_to, user_id: user_id}}
    end
  end

  @doc """
  Returns a query to find a token based on the given token and context
  """
  @spec find_by_token_and_context_query(token(), String.t()) :: Ecto.Query.t()
  def find_by_token_and_context_query(token, context) do
    from UserToken, where: [token: ^token, context: ^context]
  end

  @doc """
  Returns a query to find a token based on a given user and a list of contexts (or `:all`)
  """
  @spec find_by_user_and_context_query(User.t(), :all | nonempty_maybe_improper_list) ::
          Ecto.Query.t()
  def find_by_user_and_context_query(user, :all) do
    from t in UserToken, where: t.user_id == ^user.id
  end

  def find_by_user_and_context_query(user, [_ | _] = contexts) do
    from t in UserToken, where: t.user_id == ^user.id and t.context in ^contexts
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query, selecting on the user. The query returns the
  user found by the token, if any. The token is valid if it matches the value in the database and it has not expired
  """
  @spec verify_session_token_query(token()) :: Ecto.Query.t()
  def verify_session_token_query(token) do
    from token in find_by_token_and_context_query(token, "session"),
      join: user in assoc(token, :user),
      where: token.inserted_at > ago(@session_validity_in_days, "day"),
      select: user
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query. The query returns the user found by the token,
  if any. The token is valid if it matches the value in the database and it has not expired
  """
  @spec verify_email_token_query(token(), String.t()) :: Ecto.Query.t()
  def verify_email_token_query(token, context) do
    with hashed_token <- hash_token(token),
         days <- days_for_context(context) do
      from token in find_by_token_and_context_query(hashed_token, context),
        join: user in assoc(token, :user),
        where: token.inserted_at > ago(^days, "day") and token.sent_to == user.email,
        select: user
    end
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query. The query returns the user found by the token,
  if any. The token is valid if it matches the value in the database and it has not expired
  """
  @spec verify_change_email_token_query(encoded_token(), String.t()) ::
          {:ok, Ecto.Query.t()} | :error
  def verify_change_email_token_query(encoded_token, "change:" <> _ = context) do
    case decode_token(encoded_token) do
      {:ok, token} ->
        hashed_token = hash_token(token)

        query =
          from token in find_by_token_and_context_query(hashed_token, context),
            where: token.inserted_at > ago(@change_email_validity_in_days, "day")

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc """
  Takes a binary token and turns it into a URL-safe encoded token
  """
  @spec encode_token(token()) :: encoded_token()
  def encode_token(token) when is_binary(token) do
    Base.url_encode64(token, padding: false)
  end

  @doc """
  Takes a URL-safe encoded token and turns it into a binary token
  """
  @spec decode_token(encoded_token()) :: {:ok, token()} | :error
  def decode_token(encoded_token) do
    Base.url_decode64(encoded_token, padding: false)
  end

  @doc """
  Hashes a binary token
  """
  @spec hash_token(token()) :: binary()
  def hash_token(token) do
    :crypto.hash(@hash_algorithm, token)
  end

  defp days_for_context("confirm"), do: @confirm_validity_in_days
  defp days_for_context("reset_password"), do: @reset_password_validity_in_days
  defp days_for_context("invite"), do: @invite_validity_in_days
end
