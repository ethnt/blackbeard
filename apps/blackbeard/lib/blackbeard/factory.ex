defmodule Blackbeard.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Blackbeard.Repo

  @spec user_factory() :: %Blackbeard.Accounts.User{}
  def user_factory do
    %Blackbeard.Accounts.User{
      name: "Calico Jack",
      email: sequence(:email, &"email-#{&1}@blackbeard.video"),
      hashed_password: Argon2.hash_pwd_salt("blackbeard123"),
      confirmed_at: ~N[2024-02-29 09:00:00]
    }
  end

  @spec admin_factory() :: %Blackbeard.Accounts.User{}
  def admin_factory do
    struct!(user_factory(), %{role: :admin})
  end
end
