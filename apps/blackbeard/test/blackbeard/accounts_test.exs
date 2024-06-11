defmodule Blackbeard.AccountsTest do
  use Blackbeard.DataCase, async: true

  alias Blackbeard.Accounts
  alias Blackbeard.Accounts.{User, UserToken}

  setup do
    %{user: insert(:user)}
  end

  describe "list_users/1" do
    setup do
      %{users: insert_list(5, :user)}
    end

    test "returns all users" do
      listed_users = Accounts.list_users()

      # The 5 inserted plus the 1 from the whole test setup
      assert Enum.count(listed_users) == 6
    end
  end

  describe "find_user_by_id!/1" do
    test "raises an error if not found" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.find_user_by_id!(100_000)
      end
    end

    test "returns user with matching ID", %{user: %{id: id}} do
      assert %User{id: ^id} = Accounts.find_user_by_id!(id)
    end
  end

  describe "find_user_by_invite_token/1" do
    setup do
      email = build(:user).email

      {:ok, %{token: invite_token, user: invited_user}} =
        Accounts.invite_user(%{email: email}, fn url -> url end)

      %{invite_token: invite_token, invited_user: invited_user}
    end

    test "returns nil with no matching token" do
      refute Accounts.find_user_by_invite_token("no")
    end

    test "returns nil if token is expired", %{invite_token: invite_token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      refute Accounts.find_user_by_invite_token(invite_token)
    end

    test "returns a user", %{invite_token: invite_token, invited_user: %User{id: id}} do
      assert %User{id: ^id} = Accounts.find_user_by_invite_token(invite_token)
    end
  end

  describe "invite_user/2" do
    test "requires an email" do
      {:error, changeset} = Accounts.invite_user(%{}, fn token -> token end)

      assert "can't be blank" in errors_on(changeset).email
    end

    test "requires an email be less than 160 characters" do
      assert {:error, changeset} =
               Accounts.invite_user(%{email: String.duplicate("a", 175)}, fn token -> token end)

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "requires an email be formatted correctly" do
      assert {:error, changeset} = Accounts.invite_user(%{email: "no"}, fn token -> token end)

      assert "must have an @ sign and no spaces" in errors_on(changeset).email
    end

    test "requires an email be unique", %{user: user} do
      assert {:error, changeset} =
               Accounts.invite_user(%{email: user.email}, fn token -> token end)

      assert "has already been taken" in errors_on(changeset).email
    end

    test "returns a user" do
      email = build(:user).email

      assert {:ok, %{user: %User{email: ^email}, email: %Swoosh.Email{}}} =
               Accounts.invite_user(%{email: email}, fn token -> token end)
    end

    test "sends an email" do
      email = build(:user).email

      assert {:ok, %{user: %User{email: ^email}, email: %Swoosh.Email{} = email}} =
               Accounts.invite_user(%{email: email}, fn token -> token end)

      assert_email_sent(email)
    end

    test "creates an invite token" do
      email = build(:user).email

      assert {:ok, %{user: %User{id: user_id}, email: %Swoosh.Email{}}} =
               Accounts.invite_user(%{email: email}, fn token -> token end)

      assert Repo.get_by(UserToken, user_id: user_id, context: "invite")
    end
  end

  describe "setup_user/2" do
    setup do
      email = build(:user).email

      {:ok, %{token: invite_token, user: invited_user}} =
        Accounts.invite_user(%{email: email}, fn url -> url end)

      %{invite_token: invite_token, invited_user: invited_user}
    end

    test "returns an error with an invalid invite token" do
      assert :error = Accounts.setup_user("no", %{})
    end

    test "returns an error with an expired invite token", %{invite_token: invite_token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      assert :error = Accounts.setup_user(invite_token, %{})
    end

    test "requires a name", %{invite_token: invite_token} do
      assert {:error, %Ecto.Changeset{} = changeset} = Accounts.setup_user(invite_token, %{})

      assert "can't be blank" in errors_on(changeset).name
    end

    test "requires a password", %{invite_token: invite_token} do
      assert {:error, %Ecto.Changeset{} = changeset} = Accounts.setup_user(invite_token, %{})

      assert "can't be blank" in errors_on(changeset).password
    end

    test "requires a password to be 8 or more characters", %{invite_token: invite_token} do
      assert {:error, changeset} = Accounts.setup_user(invite_token, %{password: "no"})

      assert "should be at least 8 character(s)" in errors_on(changeset).password
    end

    test "requires a password to be less than 72 characters", %{invite_token: invite_token} do
      assert {:error, changeset} =
               Accounts.setup_user(invite_token, %{password: String.duplicate("a", 75)})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "requires the password and password confirmation to match", %{invite_token: invite_token} do
      assert {:error, changeset} =
               Accounts.setup_user(invite_token, %{
                 password: "blackbeard123",
                 password_confirmation: "nope"
               })

      assert "does not match confirmation" in errors_on(changeset).password_confirmation
    end

    test "returns an updated user", %{
      invite_token: invite_token,
      invited_user: %User{id: user_id, email: email}
    } do
      {:ok, %User{id: ^user_id} = updated_user} =
        Accounts.setup_user(invite_token, %{
          name: "Les Grossman",
          password: "blackbeard123",
          password_confirmation: "blackbeard123"
        })

      assert updated_user.email == email
      assert updated_user.name == "Les Grossman"
    end

    test "deletes the invite token", %{
      invite_token: invite_token,
      invited_user: %User{id: user_id}
    } do
      {:ok, %User{id: ^user_id}} =
        Accounts.setup_user(invite_token, %{
          name: "Les Grossman",
          password: "blackbeard123",
          password_confirmation: "blackbeard123"
        })

      refute Repo.get_by(UserToken, user_id: user_id)
    end
  end
end
