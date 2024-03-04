js_dir := "apps/blackbeard_web/assets/js"

default:
    @just --choose

install:
    mix deps.get
    cd {{ js_dir }}; pnpm install

setup:
    mix setup

console:
    iex -S mix

pnpm *ARGS:
    cd {{ js_dir }}; pnpm {{ ARGS }}

style: format lint

format:
    treefmt

lint: credo eslint

credo:
    mix credo --strict

eslint:
    cd {{ js_dir }}; pnpm eslint .

dialyzer:
    mix dialyzer

test:
    MIX_ENV=test mix do ecto.setup, test

server:
    mix phx.server

routes:
    mix phx.routes BlackbeardWeb.Router
