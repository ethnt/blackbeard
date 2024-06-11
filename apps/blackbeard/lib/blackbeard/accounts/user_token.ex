defmodule Blackbeard.Accounts.UserToken do
  @moduledoc false

  use Ecto.Schema

  alias Blackbeard.Accounts.User

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

  schema "user_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string

    timestamps(updated_at: false)

    belongs_to :user, User
  end
end
