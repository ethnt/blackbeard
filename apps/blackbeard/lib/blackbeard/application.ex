defmodule Blackbeard.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Blackbeard.Repo,
      {DNSCluster, query: Application.get_env(:blackbeard, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Blackbeard.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Blackbeard.Finch}
      # Start a worker by calling: Blackbeard.Worker.start_link(arg)
      # {Blackbeard.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Blackbeard.Supervisor)
  end
end
