defmodule Blackbeard.Umbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      dialyzer: dialyzer(),
      test_coverage: [
        ignore_modules: [
          Blackbeard,
          Blackbeard.Factory,
          Blackbeard.Repo,
          BlackbeardWeb,
          BlackbeardWeb.Application,
          BlackbeardWeb.Endpoint,
          BlackbeardWeb.Gettext,
          BlackbeardWeb.Router,
          BlackbeardWeb.Telemetry,
          ~r/\Inspect\./
        ]
      ]
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options.
  #
  # Dependencies listed here are available only for this project
  # and cannot be accessed from applications inside the apps/ folder.
  defp deps do
    [
      {:phoenix_live_view, ">= 0.0.0"},
      {:credo, "~> 1.7.4", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  #
  # Aliases listed here are available only for this project
  # and cannot be accessed from applications inside the apps/ folder.
  defp aliases do
    [
      # run `mix setup` in all child apps
      setup: ["cmd mix setup"]
    ]
  end

  # Dialyzer configuration
  defp dialyzer do
    [
      flags: [:unmatched_returns, :error_handling],
      plt_add_apps: [:mix],
      plt_core_path: "priv/plts",
      plt_file: {:no_warn, "priv/plts/blackbeard.plt"},
      ignore_warnings: ".dialyzer_ignore.exs",
      format: "dialyxir"
    ]
  end
end
