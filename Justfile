assets_dir := "apps/blackbeard_web/assets"

default:
  @just --choose

install:
    mix deps.get
    cd {{ assets_dir }}; pnpm install

setup:
    mix setup

console:
    iex -S mix

server:
    iex -S mix phx.server

pnpm *args:
    cd {{ assets_dir }}; pnpm {{ args }}

test *args:
    MIX_ENV=test mix test {{ args }}

dialyzer *args:
    mix dialyzer {{ args }}

format *args:
    treefmt {{ args }}

lint: credo eslint

credo:
    mix credo --strict

eslint:
    cd {{ assets_dir }}; pnpm eslint .
