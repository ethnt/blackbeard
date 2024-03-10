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

pnpm *args:
    cd {{ js_dir }}; pnpm {{ args }}

style: format lint

format:
    treefmt

lint: credo eslint

credo:
    mix credo --strict

eslint:
    cd {{ js_dir }}; pnpm eslint .

dialyzer *args:
    mix dialyzer {{ args }}

test *args:
    MIX_ENV=test mix do ecto.setup, test {{ args }}

debug-test:
    MIX_ENV=test iex -S mix do ecto.setup, test

generate-coverage:
    MIX_ENV=test mix do ecto.setup, test --cover --export-coverage default

coverage: generate-coverage
    mix test.coverage

server:
    mix phx.server

routes:
    mix phx.routes BlackbeardWeb.Router
