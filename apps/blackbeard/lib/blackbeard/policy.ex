defmodule Blackbeard.Policy do
  @moduledoc false

  @type action :: :create | :read | :update | :destroy

  @doc """
  Will determine if the current user can perform a designated action on the given resource
  """
  @callback can?(Blackbeard.Accounts.User.t(), action(), struct()) :: :ok | {:error, any()}
end
