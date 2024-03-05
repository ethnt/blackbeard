defmodule Blackbeard.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :name, :string, null: false
      add :email, :string, null: false
      add :hashed_password, :string, null: false
      add :role, :string, default: "user"
      add :confirmed_at, :naive_datetime

      timestamps()
    end

    create unique_index(:users, [:email])
  end
end
