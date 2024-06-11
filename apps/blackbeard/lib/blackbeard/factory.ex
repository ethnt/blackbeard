defmodule Blackbeard.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Blackbeard.Repo

  @spec user_factory() :: %Blackbeard.Accounts.User{}
  def user_factory do
    %Blackbeard.Accounts.User{
      name: "Captain Kidd",
      email: sequence(:email, &"email-#{&1}@blackbeard.video"),
      hashed_password: Bcrypt.hash_pwd_salt("blackbeard123")
    }
  end
end
