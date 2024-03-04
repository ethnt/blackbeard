defmodule BlackbeardWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use BlackbeardWeb, :controller
      use BlackbeardWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        namespace: BlackbeardWeb

      # formats: [:html, :json],
      # layouts: [html: BlackbeardWeb.Layouts]

      import Plug.Conn
      import BlackbeardWeb.Gettext

      unquote(verified_routes())
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/blackbeard_web/templates",
        namespace: BlackbeardWeb

      import Phoenix.Controller, only: [view_module: 1]
      import Phoenix.HTML
      import Phoenix.HTML.Form

      use Phoenix.Component
      use PhoenixHTMLHelpers

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {BlackbeardWeb.LayoutView, :root}
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: BlackbeardWeb.Endpoint,
        router: BlackbeardWeb.Router,
        statics: BlackbeardWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end

  defmacro __using__([{which, opts}]) when is_atom(which) do
    apply(__MODULE__, which, [List.wrap(opts)])
  end
end
