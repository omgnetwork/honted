To run two Tendermint nodes and to ABCI servers on same machine do following.

1. Run a single node HonteD-Tendermint as usual (both apps!)
7. in the `iex` REPL:

        import HonteD.API
        import HonteD.Crypto
    
        {:ok, alice_priv} = generate_private_key
        {:ok, alice_pub} = generate_public_key alice_priv
        {:ok, alice} = generate_address alice_pub
        
        raw_tx = create_create_token_transaction(alice)
        {:ok, signature} = sign(raw_tx, alice_priv)
        {:ok, hash} = submit_transaction raw_tx <> " " <> signature
        
        # wait
        
        {:ok, decoded_tx} = tx(hash)["decoded_tx"]
        {:ok, {nonce, :create_token, issuer, _ }} = HonteD.TxCodec.decode(decoded_tx)
        asset = HonteD.Token.create_address(issuer, nonce)
        
        raw_tx = create_issue_transaction(asset, 5, alice, alice)
        {:ok, signature} = sign(raw_tx, alice_priv)
        submit_transaction raw_tx <> " " <> signature
        
        # wait

        query_balance(asset, alice)
