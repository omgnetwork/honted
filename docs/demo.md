To run two Tendermint nodes and to ABCI servers on same machine do following.

1) run first node and ABCI server as usual
2) `cp -r ~/.tendermint ~/.tendermint2`
3) `rm ~/.tendermint2/data ~/.tendermint2/priv_validator.json`
4) replace ~/.tendermint2/config.toml with following:

###
proxy_app = "tcp://127.0.0.1:46668"
moniker = "anonymous"
fast_sync = true
db_backend = "leveldb"
log_level = "state:info,*:error"

[rpc]
laddr = "tcp://0.0.0.0:46667"

[p2p]
laddr = "tcp://0.0.0.0:46666"
seeds = "127.0.0.1:46656"
###

5) second ABCI node: `mix run --config config/config.exs --no-halt`
6) second T node: `tendermint --home ~/.tendermint2 node`


