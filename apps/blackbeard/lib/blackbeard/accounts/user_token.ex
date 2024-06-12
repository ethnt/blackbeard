defmodule Blackbeard.Accounts.UserToken do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Query

  alias Blackbeard.Accounts.{User, UserToken}

  @type t :: %__MODULE__{
          id: integer(),
          token: token(),
          context: String.t(),
          sent_to: String.t(),
          user: User.t() | nil,
          user_id: integer(),
          inserted_at: NaiveDateTime.t()
        }

  @typedoc """
  Represents a token that's stored in a signed place, and therefore does not to be hashed. This is the "raw"
  representation of the token
  """
  @type token :: binary()

  @typedoc """
  Represents a token that's stored in an insecure place (like an email), and is hashed
  """
  @type hashed_token :: binary()

  @typedoc """
  Represents a token that is encoded into a string form
  """
  @type encoded_token :: String.t()

  @hash_algorithm :sha256
  @rand_size 32

  @invite_validity_in_days 7
  @session_validity_in_days 60
  @reset_password_validity_in_days 1

  schema "user_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string

    timestamps(updated_at: false)

    belongs_to :user, User
  end

  @doc """
  Builds a token that will be stored in a signed place, such as a session or cookie
  """
  @spec build_session_token(User.t()) :: {token(), %UserToken{}}
  def build_session_token(user) do
    token = generate_token()
    {token, %UserToken{token: token, context: "session", user_id: user.id}}
  end

  @doc """
  Builds a token that can be sent to the user. The non-hashed version is sent to the user, while the hashed part is
  stored in the database. The original token cannot be reconstructed, which means anyone who might have read-only access
  to the database cannot directly use the token to gain access. In the event that the user changes their email, the
  tokens sent to the previous email are no longer valid
  """
  @spec build_email_token(User.t(), String.t()) :: {encoded_token(), %UserToken{}}
  def build_email_token(user, context) do
    build_hashed_token(user, context, user.email)
  end

  @spec build_hashed_token(User.t(), String.t(), String.t()) :: {encoded_token(), %UserToken{}}
  defp build_hashed_token(user, context, sent_to) do
    with token <- generate_token(),
         hashed_token <- hash_token(token),
         encoded_token <- encode_token(token),
         user_token <- %UserToken{
           token: hashed_token,
           context: context,
           sent_to: sent_to,
           user_id: user.id
         } do
      {encoded_token, user_token}
    end
  end

  @doc """
  Checks if a token is valid and returns a query that will return the user associated with that token
  """
  @spec verify_email_token_query(encoded_token(), String.t()) :: {:ok, Ecto.Query.t()} | :error
  def verify_email_token_query(encoded_token, context) do
    case decode_token(encoded_token) do
      {:ok, decoded_token} ->
        hashed_token = hash_token(decoded_token)
        days = days_for_context(context)

        query =
          from token in find_by_token_and_context_query(hashed_token, context),
            join: user in assoc(token, :user),
            where: token.inserted_at > ago(^days, "day") and token.sent_to == user.email,
            select: user

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc """
  Checks if a token is valid and returns a query that will return the user associated with that session token
  """
  @spec verify_session_token_query(token()) :: {:ok, Ecto.Query.t()}
  def verify_session_token_query(token) do
    query =
      from token in find_by_token_and_context_query(token, "session"),
        join: user in assoc(token, :user),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: user

    {:ok, query}
  end

  @spec find_by_user_and_contexts_query(User.t(), :all | list()) :: Ecto.Query.t()
  def find_by_user_and_contexts_query(user, :all) do
    from t in UserToken, where: t.user_id == ^user.id
  end

  def find_by_user_and_contexts_query(user, [_ | _] = contexts) do
    from t in UserToken, where: t.user_id == ^user.id and t.context in ^contexts
  end

  @spec find_by_token_and_context_query(token() | hashed_token(), String.t()) :: Ecto.Query.t()
  def find_by_token_and_context_query(token, context) do
    from UserToken, where: [token: ^token, context: ^context]
  end

  @spec generate_token() :: token()
  def generate_token do
    :crypto.strong_rand_bytes(@rand_size)
  end

  @spec hash_token(token()) :: hashed_token()
  def hash_token(token) do
    :crypto.hash(@hash_algorithm, token)
  end

  @spec encode_token(token()) :: encoded_token()
  def encode_token(token) do
    Base.url_encode64(token, padding: false)
  end

  @spec decode_token(encoded_token()) :: {:ok, token()} | :error
  def decode_token(encoded_token) do
    Base.url_decode64(encoded_token, padding: false)
  end

  defp days_for_context("invite"), do: @invite_validity_in_days
  defp days_for_context("reset_password"), do: @reset_password_validity_in_days
end
