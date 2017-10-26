To run two Tendermint nodes and to ABCI servers on same machine do following.

1. Run a single node HonteD-Tendermint as usual (both apps!)
7. in `iex`/`wscat`/shell:

        # v PREPARATIONS v
        
        import HonteD.API
        import HonteD.Crypto
    
        {:ok, alice_priv} = generate_private_key
        {:ok, alice_pub} = generate_public_key alice_priv
        {:ok, alice} = generate_address alice_pub
        
        {:ok, raw_tx} = create_create_token_transaction(alice)
        {:ok, signature} = sign(raw_tx, alice_priv)
        {:ok, hash} = submit_transaction raw_tx <> " " <> signature
        
        # v START DEMO HERE v
        
        {:ok, [asset]} = tokens_issued_by(alice)
        
        {:ok, raw_tx} = create_issue_transaction(asset, 5, alice, alice)
        {:ok, signature} = sign(raw_tx, alice_priv)
        submit_transaction raw_tx <> " " <> signature
        
        # wait

        query_balance(asset, alice)
        token_info(asset)
        
        alice
        
        # query balance using websockets
        # {"wsrpc": "1.0", "type": "rq", "method": "query_balance", "params": {"token": "", "address": ""}}
        # query issued tokens using websockets
        # {"wsrpc": "1.0", "type": "rq", "method": "tokens_issued_by", "params": {"issuer": ""}}
        # query token info using json rpc
        # http --json localhost:4000 method=token_info params:='{"token": ""}' jsonrpc=2.0 id=1
        
        # subscribe to filter
        # {"wsrpc": "1.0", "type": "rq", "method": "send_filter_new", "params": {"subscriber": "", "watched": ""}}
        
        {:ok, raw_tx} = create_send_transaction(asset, 5, alice, alice)
        {:ok, signature} = sign(raw_tx, alice_priv)
        submit_transaction raw_tx <> " " <> signature
