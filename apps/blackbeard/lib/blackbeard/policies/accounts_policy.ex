defmodule Blackbeard.Policies.AccountsPolicy do
  @behaviour Blackbeard.Policy

  alias Blackbeard.Accounts

  @spec can?(
          Blackbeard.Accounts.User.t(),
          Blackbeard.Policy.action(),
          Blackbeard.Accounts.User.t()
        ) :: :ok | {:error, any()}
  def can?(%Accounts.User{role: :user, id: current_user_id}, action, %Accounts.User{id: user_id})
      when action in [:read, :update, :destroy] and current_user_id == user_id,
      do: :ok

  def can?(%Accounts.User{role: :admin}, _action, _user), do: :ok

  def can?(_current_user, _action, _user), do: {:error, :not_allowed}
end
