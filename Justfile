default:
  @just --choose

install:
    mix deps.get

setup:
    mix setup

console:
    iex -S mix

server:
    iex -S mix phx.server

test *args:
    MIX_ENV=test mix test {{ args }}

dialyzer *args:
    mix dialyzer {{ args }}

format:
    treefmt

lint: credo

credo:
    mix credo --strict
