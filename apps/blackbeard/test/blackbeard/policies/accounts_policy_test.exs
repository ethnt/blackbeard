defmodule Blackbeard.Policies.AccountsPolicyTest do
  use Blackbeard.DataCase, async: true

  alias Blackbeard.Accounts
  alias Blackbeard.Policies.AccountsPolicy

  setup do
    %{admin: insert(:admin), user: insert(:user), other: insert(:user)}
  end

  describe "user" do
    test "cannot create users", %{user: user} do
      assert {:error, :not_allowed} = AccountsPolicy.can?(user, :create, %Accounts.User{})
    end

    test "can read themselves", %{user: user} do
      assert :ok = AccountsPolicy.can?(user, :read, user)
    end

    test "cannot read others", %{user: user, other: other} do
      assert {:error, :not_allowed} = AccountsPolicy.can?(user, :read, other)
    end

    test "can update themselves", %{user: user} do
      assert :ok = AccountsPolicy.can?(user, :update, user)
    end

    test "cannot update others", %{user: user, other: other} do
      assert {:error, :not_allowed} = AccountsPolicy.can?(user, :update, other)
    end

    test "can destroy themselves", %{user: user} do
      assert :ok = AccountsPolicy.can?(user, :destroy, user)
    end

    test "cannot destroy others", %{user: user, other: other} do
      assert {:error, :not_allowed} = AccountsPolicy.can?(user, :destroy, other)
    end
  end

  describe "admin" do
    test "can read users", %{admin: admin} do
      assert :ok = AccountsPolicy.can?(admin, :read, %Accounts.User{})
    end

    test "can create users", %{admin: admin} do
      assert :ok = AccountsPolicy.can?(admin, :create, %Accounts.User{})
    end

    test "can update users", %{admin: admin} do
      assert :ok = AccountsPolicy.can?(admin, :update, %Accounts.User{})
    end

    test "can destroy users", %{admin: admin} do
      assert :ok = AccountsPolicy.can?(admin, :destroy, %Accounts.User{})
    end
  end
end
