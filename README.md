# HonteD

## Installation

### Prerequisites

Only **Linux** platforms supported now. Known to work with Ubuntu 16.04

Install [Elixir](http://elixir-lang.github.io/install.html#unix-and-unix-like).
Make sure `rebar` is in your path, e.g. `export PATH=$PATH:~/.mix` (mileage may vary).

Install Tendermint [from source](https://tendermint.readthedocs.io/en/master/install.html#from-source) (`golang` > `v1.9` and `glide` is required).

Install Rust and cargo (https://doc.rust-lang.org/cargo/getting-started/installation.html).

**NOTE** Validator set updates work only with a temporary branch [here](https://github.com/omisego/tendermint/tree/v0.15.0_dirty_no_val_check).
Check out and install this, for example like this:

```bash
cd $GOPATH/src/github.com/tendermint/tendermint
git remote add omisego https://github.com/omisego/tendermint
git fetch omisego
git checkout v0.15.0_dirty_no_val_check
glide install
go install ./cmd/tendermint
```

This is necessary because Tendermint `v0.15.0` imposed a limit on voting power change (<1/3 per block),
which will be removed in `v0.16.0`, that hasn't yet been released.
Hence, we need to use our fork which lifts this limit.

### HonteD

  - `git clone github.com/omisego/honted` - clone this repo
  - `cd honted`
  - `mix deps.get`
  - `iex -S mix`
  - elsewhere:
    - `tendermint init` (once)
    - `tendermint --log_level "*:info" node` (everytime to start Tendermint)
  - then in the `iex` REPL you can run commands using `HonteD.API`, e.g. ones mentioned in demos (see `docs/...`, don't pick `OBSOLETE` demos)

Do `tendermint unsafe_reset_all && tendermint init` every time you want to clean the databases and start from scratch.

## Testing

 - quick test (no integration tests): `mix test --no-start`
 - long running unit tests: `mix test --no-start --only slow`
 - longer-running integration tests: `mix test --no-start --only integration`
 - everything: `mix test --no-start --include integration --include slow`
 - Dialyzer: `mix dialyzer`. First run will build the PLT, so may take several minutes
 - style & linting: `mix credo`. (`--strict` is switched on by default)
 - coverage: `mix coveralls.html --umbrella --no-start --include integration slow`

### Integration tests

**NOTE** Integration tests require `tm-bench` to be installed: `go get -u github.com/tendermint/tools/tm-bench`, possibly a `cd $GOPATH/src/github.com/tendermint/tools/tm-bench && glide install && go install .` will be necessary

When running `integration` tests, remember to have `tendermint`, `tm-bench`, and `geth` binaries reachable in your `$PATH`.

When running `integration` tests, remember to install `populus` and `populus compile` the contracts, like so:
```bash
sudo apt-get install libssl-dev
sudo apt-get install solc
cd populus
pip install -r requirements.txt
populus compile
```

Assuming you have `python` and `pip` installed, using `virtualenv` is recommended.

### Performance test - quick guide

In the same setup as for the Integration tests, run e.g.:
```
mix run --no-start -e 'HonteD.PerftestScript.setup_and_run(5, 0, 100)'
```

for more details see the `moduledoc` therein.

**NOTE** with this Tendermint version you may get weird `:invalid_nonce` errors sometimes.
`v0.16` should fix this.

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
  - `honted_eth` - fetches information about validators set from Ethereum and feeds it into `honted_abci`
  - `honted_integration` - just for integration/performance testing
  - `honted_jsonrpc` - a JSONRPC 2.0 gateway to `honted_api` - automatically exposed via `ExposeSpec`
  - `honted_ws` - a Websockets gateway to `honted_api` - automatically exposed via `ExposeSpec`
  - `honted_lib` - all stateless and generic functionality, shared application logic

## Staking

We assume, that an appropriate Ethereum client is exposing its RPC for `honted_eth`
and that appropriate contracts have been deployed and are operated according to their documentation
(currently - documentation in contract code in `contracts`).

To configure HonteD node to use a particular staking contract,
copy `apps/honted_eth/config.exs` to `apps/honted_eth/local_staking_config.exs`,
switch the `enabled` flag to `true` and modify the config appropriately.
Then use the edited config file to run `honted`.
