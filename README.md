# HonteD

## Quick guide

Only **Linux** platforms supported now. Known to work with Ubuntu 16.04

Install [Elixir](http://elixir-lang.github.io/install.html#unix-and-unix-like).

Install [Tendermint](https://tendermint.com/downloads). **NOTE** we require Tendermint `v0.14.0` and this in turn requires `golang` > `v1.9` (works with `v1.9.2`). In order to do that, `git checkout` the above tag for Tendermint repo in your `$GOPATH`, then (optionally) `glide install` and `go install github.com/tendermint/tendermint/cmd/tendermint`.

  - `git clone ...` - clone this repo
  - `mix deps.get`
  - `iex -S mix`
  - elsewhere:
    - `tendermint init` (once)
    - `tendermint --log_level "*:info" node` (everytime to start Tendermint)
  - then in the `iex` REPL you can run commands using HonteDAPI, e.g. ones mentioned in most recent demo (see `docs/...`)

Do `tendermint unsafe_reset_all && tendermint init` every time you want to clean the databases and start from scratch.

## Testing

 - quick test (no integration tests): `mix test --no-start`
 - longer-running integration tests: `mix test --no-start --only integration`
 - everything: `mix test --no-start --include integration`
 - Dialyzer: `mix dialyzer`. First run will build the PLT, so may take several minutes
 - style & linting: `mix credo`. (`--strict` is switched on by default)
 - coverage: `mix coveralls.html --umbrella --no-start --include integration`

### Integration tests

**NOTE** Integration tests require `tm-bench` to be installed: `go get -u github.com/tendermint/tools/tm-bench`, possibly a `glide install` will be necessary

When running `integration` tests, remember to have `tendermint` and `tm-bench` binaries reachable in your `$PATH`.

### Performance test - quick guide

In the same setup as for the Integration tests, run e.g.:
```
mix run --no-start -e 'HonteD.PerftestScript.setup_and_run(5, 0, 100)'
```

for more details see the `moduledoc` therein

## Using the APIs

### JSONRPC 2.0

JSONRPC 2.0 requests are listened on on the port specified in `honted_jsonrpc`'s `config`.
The available RPC calls are defined by `honted_api` in `api.ex` - the functions are `method` names and their respective arguments make the dictionary sent as `params`.
The argument names are indicated by the `@spec` clauses.

**NOTE** JSONRPC 2.0 doesn't support the methods related to events/filters

### Websockets

Websocket connections are listened on on the port specified in `honted_ws`'s `config`.
Same considerations with respect to method and parameters' names apply as with JSONRPC 2.0.
The calls to the Websocket RPC are structured in a pseudo-JSONRPC-like manner:

Example call string to send to the socket would be:
```
{"wsrpc": "1.0", "type": "rq", "method": "new_send_filter", "params": {"watched": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}}
```

## Overview of apps

HonteD is an umbrella app comprising several Elixir applications.
See the apps' respective `moduledoc`'s' for their respective overviews and documentation.

The general idea of the apps responsibilities is:
  - `honted_abci` - talks to Tendermint core and maintains the state, including validator selection and tracking the staking mechanism on Ethereum
  - `honted_api` - main entrypoint to the functionality. Interacts with the blockchain via Tendermint APIs
  - `honted_integration` - just for integration/performance testing
  - `honted_jsonrpc` - a JSONRPC 2.0 gateway to `honted_api` - automatically exposed via `ExposeSpec`
  - `honted_ws` - a Websockets gateway to `honted_api` - automatically exposed via `ExposeSpec`
  - `honted_lib` - all stateless and generic functionality, shared application logic
