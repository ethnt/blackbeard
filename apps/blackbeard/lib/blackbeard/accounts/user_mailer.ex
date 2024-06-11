defmodule Blackbeard.Accounts.UserMailer do
  @moduledoc false

  import Swoosh.Email

  alias Blackbeard.Accounts.User
  alias Blackbeard.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Blackbeard", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to accept invitation
  """
  @spec deliver_invitation_instructions(User.t(), String.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, any()}
  def deliver_invitation_instructions(user, url) do
    deliver(user.email, "Invitation to use Blackbeard", """

    ==============================

    Hi #{user.email},

    You can accept your invite to use Blackbeard by visiting the URL below:

    #{url}

    ==============================
    """)
  end
end
