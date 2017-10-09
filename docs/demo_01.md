To run two Tendermint nodes and to ABCI servers on same machine do following.

1. `tendermint init` as usual (no `unsafe_reset_all`)
2. `cp -r ~/.tendermint ~/.tendermint2`
3. `rm ~/.tendermint2/priv_validator.json`
4. replace `~/.tendermint2/config.toml` with following:

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

1. run first node and ABCI server as usual (`tendermint node`)
5. copy the config file for the second ABCI node from `config/config.exs` to `config/config2.exs`
6. modify the `config/config2.exs` accordingly to the above `config.toml`
5. second ABCI node: `iex -S mix run --config config/config2.exs`
6. second T node: `tendermint --home ~/.tendermint2 node`
7. in the one of the `iex` REPLs:

        import HonteD.API
        import HonteD.Crypto
    
        {:ok, alice_priv} = generate_private_key
        {:ok, alice_pub} = generate_public_key alice_priv
        {:ok, alice} = generate_address alice_pub
        {:ok, bob_priv} = generate_private_key
        {:ok, bob_pub} = generate_public_key bob_priv
        {:ok, bob} = generate_address bob_pub
        submit_transaction("ISSUE asset 5 #{alice}")
        
        raw_tx = create_send_transaction("asset", 1, alice, bob)
        {:ok, signature} = sign(raw_tx, alice_priv)
        submit_transaction raw_tx <> " " <> signature
        
        query_balance("asset", alice)
