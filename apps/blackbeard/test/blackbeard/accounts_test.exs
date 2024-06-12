defmodule Blackbeard.AccountsTest do
  use Blackbeard.DataCase, async: true

  alias Blackbeard.Accounts
  alias Blackbeard.Accounts.{User, UserToken}

  setup do
    %{user: insert(:user)}
  end

  ### Finders

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

  describe "find_user_by_email/1" do
    test "returns nil with no results" do
      refute Accounts.find_user_by_email("no")
    end

    test "returns a matching user", %{user: %{id: id, email: email}} do
      %User{id: ^id} = Accounts.find_user_by_email(email)
    end
  end

  describe "find_user_by_email_and_password/2" do
    test "returns nil with no matching email" do
      refute Accounts.find_user_by_email_and_password("no", "no")
    end

    test "returns nil with no matching password", %{user: user} do
      refute Accounts.find_user_by_email_and_password(user.email, "no")
    end

    test "returns a matching user", %{user: %{id: id, email: email}} do
      %User{id: ^id} = Accounts.find_user_by_email_and_password(email, "blackbeard123")
    end
  end

  ### Sessions

  describe "find_user_by_session_token/1" do
    setup %{user: user} do
      token = Accounts.create_user_session_token(user)

      %{token: token}
    end

    test "returns nil with no matching token" do
      refute Accounts.find_user_by_session_token("no")
    end

    test "returns nil with an expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      refute Accounts.find_user_by_session_token(token)
    end

    test "returns a matching user", %{user: %{id: id}, token: token} do
      assert %User{id: ^id} = Accounts.find_user_by_session_token(token)
    end
  end

  describe "create_user_session_token/1" do
    test "creates a token", %{user: user} do
      token = Accounts.create_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"
    end
  end

  describe "destroy_user_session_token/1" do
    setup %{user: user} do
      token = Accounts.create_user_session_token(user)

      %{token: token}
    end

    test "destroys the token", %{token: token} do
      Accounts.destroy_user_session_token(token)

      refute Repo.get_by(UserToken, token: token)
    end
  end

  ### Invitations

  describe "invite_user/2" do
    test "requires an email" do
      assert {:error, changeset} = Accounts.invite_user(%{}, fn token -> token end)

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

  describe "invite_user_changeset/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.invite_user_changeset(%User{})
      assert changeset.required == [:email]
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

  ### Setup

  describe "setup_user/2" do
    setup do
      email = build(:user).email

      {:ok, %{user: invited_user}} =
        Accounts.invite_user(%{email: email}, fn url -> url end)

      %{invited_user: invited_user}
    end

    test "requires a name", %{invited_user: invited_user} do
      assert {:error, %Ecto.Changeset{} = changeset} = Accounts.setup_user(invited_user, %{})

      assert "can't be blank" in errors_on(changeset).name
    end

    test "requires a password", %{invited_user: invited_user} do
      assert {:error, %Ecto.Changeset{} = changeset} = Accounts.setup_user(invited_user, %{})

      assert "can't be blank" in errors_on(changeset).password
    end

    test "requires a password to be 8 or more characters", %{invited_user: invited_user} do
      assert {:error, changeset} = Accounts.setup_user(invited_user, %{password: "no"})

      assert "should be at least 8 character(s)" in errors_on(changeset).password
    end

    test "requires a password to be less than 72 characters", %{invited_user: invited_user} do
      assert {:error, changeset} =
               Accounts.setup_user(invited_user, %{password: String.duplicate("a", 75)})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "requires the password and password confirmation to match", %{invited_user: invited_user} do
      assert {:error, changeset} =
               Accounts.setup_user(invited_user, %{
                 password: "blackbeard123",
                 password_confirmation: "nope"
               })

      assert "does not match password" in errors_on(changeset).password_confirmation
    end

    test "returns an updated user", %{
      invited_user: %User{id: user_id, email: email} = invited_user
    } do
      {:ok, %User{id: ^user_id} = updated_user} =
        Accounts.setup_user(invited_user, %{
          name: "Les Grossman",
          password: "blackbeard123",
          password_confirmation: "blackbeard123"
        })

      assert updated_user.email == email
      assert updated_user.name == "Les Grossman"
    end

    test "deletes the invite token", %{invited_user: %User{id: user_id} = invited_user} do
      {:ok, %User{id: ^user_id}} =
        Accounts.setup_user(invited_user, %{
          name: "Les Grossman",
          password: "blackbeard123",
          password_confirmation: "blackbeard123"
        })

      refute Repo.get_by(UserToken, user_id: user_id)
    end
  end

  describe "setup_user_changeset/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.setup_user_changeset(%User{})
      assert changeset.required == [:password, :name]
    end
  end

  ### Reset password

  describe "forgot_user_password/2" do
    test "sends an email for an existing user", %{user: %{email: email}} do
      assert :ok = Accounts.forgot_user_password(%{email: email}, fn url -> url end)

      assert_email_sent()
    end

    test "does not send an email for a non-existant user" do
      assert :ok = Accounts.forgot_user_password(%{email: "no@bar.com"}, fn url -> url end)

      refute_email_sent()
    end
  end

  describe "deliver_user_reset_password_instructions/2" do
    test "creates and sends a token via email", %{user: %{id: user_id, email: email} = user} do
      token =
        extract_user_token_from_email(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      {:ok, token} = UserToken.decode_token(token)

      assert %UserToken{user_id: ^user_id, sent_to: ^email, context: "reset_password"} =
               Repo.get_by(UserToken, token: UserToken.hash_token(token))
    end
  end

  describe "find_user_by_reset_password_token/1" do
    setup %{user: user} do
      token =
        extract_user_token_from_email(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      %{token: token}
    end

    test "returns nil with no matching token" do
      refute Accounts.find_user_by_reset_password_token("no")
    end

    test "returns nil with an expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      refute Accounts.find_user_by_reset_password_token(token)
    end

    test "returns a matching user", %{user: %{id: id}, token: token} do
      assert %User{id: ^id} = Accounts.find_user_by_reset_password_token(token)
    end
  end

  describe "reset_user_password/2" do
    test "requires a password", %{user: user} do
      assert {:error, changeset} = Accounts.reset_user_password(user, %{})

      assert "can't be blank" in errors_on(changeset).password
    end

    test "requires a password to be 8 or more characters", %{user: user} do
      assert {:error, changeset} =
               Accounts.reset_user_password(user, %{
                 password: "no",
                 password_confirmation: "no"
               })

      assert "should be at least 8 character(s)" in errors_on(changeset).password
    end

    test "requires a password to be less than 72 characters", %{user: user} do
      assert {:error, changeset} =
               Accounts.reset_user_password(user, %{
                 password: String.duplicate("a", 75),
                 password_confirmation: String.duplicate("a", 75)
               })

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the user's password", %{user: %{id: id} = user} do
      {:ok, %User{} = user} =
        Accounts.reset_user_password(user, %{
          password: "foobar123",
          password_confirmation: "foobar123"
        })

      assert %User{id: ^id} = Accounts.find_user_by_email_and_password(user.email, "foobar123")
    end

    test "deletes all tokens for the user", %{user: user} do
      _ = Accounts.create_user_session_token(user)

      {:ok, _} =
        Accounts.reset_user_password(user, %{
          password: "foobar123",
          password_confirmation: "foobar123"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "update_user_password_changeset/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.update_user_password_changeset(%User{})
      assert changeset.required == [:password]
    end
  end

  ### Updating/deleting

  describe "update_user/2" do
    test "requires a name", %{user: user} do
      assert {:error, %Ecto.Changeset{} = changeset} = Accounts.update_user(user, %{name: nil})

      assert "can't be blank" in errors_on(changeset).name
    end

    test "requires an email", %{user: user} do
      assert {:error, changeset} = Accounts.update_user(user, %{email: nil})

      assert "can't be blank" in errors_on(changeset).email
    end

    test "requires an email be less than 160 characters", %{user: user} do
      assert {:error, changeset} =
               Accounts.update_user(user, %{email: String.duplicate("a", 175)})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "requires an email be formatted correctly", %{user: user} do
      assert {:error, changeset} = Accounts.update_user(user, %{email: "no"})

      assert "must have an @ sign and no spaces" in errors_on(changeset).email
    end

    test "requires an email be unique", %{user: user} do
      other_user = insert(:user)

      assert {:error, changeset} = Accounts.update_user(user, %{email: other_user.email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "updates the user", %{user: %User{id: id} = user} do
      email = build(:user).email

      assert {:ok, %User{id: ^id} = updated_user} =
               Accounts.update_user(user, %{name: "Les Grossman", email: email})

      assert updated_user.name == "Les Grossman"
      assert updated_user.email == email
    end
  end

  describe "update_user_changeset/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.update_user_changeset(%User{})
      assert changeset.required == [:email, :name]
    end
  end

  describe "destroy_user/1" do
    test "deletes the user", %{user: %User{id: id} = user} do
      {:ok, %User{id: ^id}} = Accounts.destroy_user(user)

      refute Repo.get(User, id)
    end
  end

  describe "User.inspect/2" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
