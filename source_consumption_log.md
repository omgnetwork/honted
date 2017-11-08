# Source Consumption Log

### About:

Identifies each module of pre-existing source code used in developing source code, what license (if any) that source code was provided under, where the preexisting source code and the license can be obtained publicly (if so available), and identification of where that source is located.

## Redistributed already

* Elixir/Erlang/BEAM/OTP
  * `Elixir`, Apache 2.0, https://github.com/elixir-lang/elixir
  * `Erlang`, Apache 2.0, https://www.erlang.org
  * `BEAM/OTP`, Apache 2.0, https://github.com/erlang/otp
* MIX deps, as listed by the `mix.exs` of applications in `honted` repo
  * `abci_server`, Apache 2.0, https://github.com/KrzysiekJ/abci_server
  * `bimap`, MIT, https://hex.pm/packages/bimap
  * `cowboy`, ISC, https://hex.pm/packages/cowboy
  * `cowlib`, ISC, https://hex.pm/packages/cowlib
  * `credo`, MIT, https://hex.pm/packages/credo
  * `dialyxir`, Apache 2.0, https://hex.pm/packages/dialyxir
  * `ex_unit_fixtures`, MIT, https://hex.pm/packages/ex_unit_fixtures
  * `jsonrpc2`, Apache 2.0, https://hex.pm/packages/jsonrpc2
  * `mime`, Apache 2.0, https://hex.pm/packages/mime
  * **(!) but this is a temporary dependency** `ojson`, Mozilla Public 2.0, https://hex.pm/packages/ojson
  * `plug`, Apache 2.0, https://hex.pm/packages/plug
  * **(!)** `poison`, CC0-1.0, https://hex.pm/packages/poison
  * `ranch`, ISC, https://hex.pm/packages/ranch
  * `tesla`, MIT, https://hex.pm/packages/tesla
* `tendermint`, Apache 2.0, https://github.com/tendermint/tendermint
  
## Likely to be redistributed

* MIX deps...
  * `mock`, MIT, https://hex.pm/packages/mock
* `geth`, LGPL 3.0, https://github.com/ethereum/go-ethereum, (used via an interface, so ok)
* `zeppelin-solidity`, MIT, https://github.com/OpenZeppelin/zeppelin-solidity

## Likely to be used, but not redistributed

* `populus/web3.py/et al.`, MIT, https://pypi.python.org/pypi/populus/1.11.0
* `solc`, GPL 3.0, https://github.com/ethereum/solidity
