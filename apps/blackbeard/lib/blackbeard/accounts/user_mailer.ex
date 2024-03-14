defmodule Blackbeard.Accounts.UserMailer do
  @moduledoc false

  import Swoosh.Email

  alias Blackbeard.Accounts.User
  alias Blackbeard.Mailer

  @spec deliver(String.t(), String.t(), String.t()) :: {:ok, Swoosh.Email.t()} | {:error, any()}
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Copilot", "contact@getcopilot.app"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @spec deliver_confirmation_instructions(User.t(), String.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, any()}
  def deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Copilot: Confirmation instructions", """
    Hi,

    You can confirm your Copilot account by visiting the URL below:

    #{url}

    If you didn't create an account with us, ignore this email.
    """)
  end

  @spec deliver_invitation_instructions(User.t(), String.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, any()}
  def deliver_invitation_instructions(user, url) do
    deliver(user.email, "Blackbeard: Invitation instructions", """
    Hi,

    You can confirm your Blackbeard account by visiting the URL below:

    #{url}

    If you didn't create an account with us, ignore this email.
    """)
  end

  @spec deliver_reset_password_instructions(User.t(), String.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, any()}
  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, "Copilot: Reset password instructions", """
    Hi,

    You can reset the password on your Copilot account by visiting the URL below:

    #{url}

    If you didn't create an account with us, ignore this email.
    """)
  end

  @spec deliver_update_email_instructions(User.t(), String.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, any()}
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Copilot: Update email instructions", """
    Hi,

    You can update the email on your Copilot account by visiting the URL below:

    #{url}

    If you didn't create an account with us, ignore this email.
    """)
  end
end
