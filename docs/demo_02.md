To run two Tendermint nodes and to ABCI servers on same machine do following.

1. Run a single node HonteD-Tendermint as usual (both apps!)
7. in the `iex` REPL:

        import HonteD.API
        import HonteD.Crypto
    
        {:ok, alice_priv} = generate_private_key
        {:ok, alice_pub} = generate_public_key alice_priv
        {:ok, alice} = generate_address alice_pub
        
        {:ok, raw_tx} = create_create_token_transaction(alice)
        {:ok, signature} = sign(raw_tx, alice_priv)
        {:ok, hash} = submit_transaction raw_tx <> " " <> signature
        
        # wait
        
        {:ok, [asset]} = tokens_issued_by(alice)
        
        {:ok, raw_tx} = create_issue_transaction(asset, 5, alice, alice)
        {:ok, signature} = sign(raw_tx, alice_priv)
        submit_transaction raw_tx <> " " <> signature
        
        # wait

        token_info(asset)
        query_balance(asset, alice)
