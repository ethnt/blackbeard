defmodule Blackbeard.Policy do
  @type action :: :create | :read | :update | :destroy

  @callback can?(Blackbeard.Accounts.User.t(), action(), struct()) :: :ok | {:error, any()}
end
