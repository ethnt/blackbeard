defmodule Blackbeard.AccountsTest do
  @moduledoc false

  use Blackbeard.DataCase, async: true

  alias Blackbeard.Accounts
  alias Blackbeard.Accounts.User

  setup do
    %{user: insert(:user)}
  end

  describe "find_user_by_id!/1" do
    test "returns user", %{user: user} do
      assert %User{} = returned_user = Accounts.find_user_by_id!(user.id)
      assert returned_user.id == user.id
    end

    test "raises error when not found" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.find_user_by_id!(100_000)
      end
    end
  end

  describe "find_user_by_email/1" do
    test "returns nil with no results" do
      refute Accounts.find_user_by_email("no")
    end

    test "returns a matching user", %{user: user} do
      %User{} = returned_user = Accounts.find_user_by_email(user.email)

      assert returned_user.id == user.id
    end
  end

  describe "find_user_by_email_and_password/2" do
    test "returns nil with no matching email" do
      refute Accounts.find_user_by_email_and_password("no", "no")
    end

    test "returns nil with no matching password", %{user: user} do
      refute Accounts.find_user_by_email_and_password(user.email, "no")
    end

    test "returns a matching user", %{user: user} do
      %User{} = returned_user = Accounts.find_user_by_email_and_password(user.email, "blackbeard123")

      assert returned_user.id == user.id
    end
  end

  describe "create_user/3" do
    test "requires a name" do
      {:error, changeset} = Accounts.create_user(%{})

      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires an email" do
      {:error, changeset} = Accounts.create_user(%{})

      assert "can't be blank" in errors_on(changeset).email
    end

    test "requires an email be less than 160 characters" do
      {:error, changeset} = Accounts.create_user(%{email: String.duplicate("a", 175)})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "requires an email be formatted correctly" do
      {:error, changeset} = Accounts.create_user(%{email: "no"})

      assert "must have an @ sign and no spaces" in errors_on(changeset).email
    end

    test "requires an email be unique", %{user: user} do
      {:error, changeset} = Accounts.create_user(%{email: user.email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "requires a password" do
      {:error, changeset} = Accounts.create_user(%{})

      assert "can't be blank" in errors_on(changeset).password
    end

    test "requires a password to be 8 or more characters" do
      {:error, changeset} = Accounts.create_user(%{password: "no"})

      assert "should be at least 8 character(s)" in errors_on(changeset).password
    end

    test "requires a password to be less than 72 characters" do
      {:error, changeset} = Accounts.create_user(%{password: String.duplicate("a", 75)})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "returns a user" do
      email = "user#{System.unique_integer()}@example.com"

      {:ok, user} =
        Accounts.create_user(%{
          name: "Foobar",
          email: email,
          password: "copilot123"
        })

      assert user.name == "Foobar"
      assert user.email == email
      assert is_binary(user.hashed_password)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end
  end

  describe "create_user_changeset/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.create_user_changeset(%User{})
      assert changeset.required == [:password, :email, :name]
    end
  end
end
