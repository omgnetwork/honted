To run two Tendermint nodes and to ABCI servers on same machine do following.

1. Run a single node HonteD-Tendermint as usual (both apps!)
7. in `iex`/`wscat`/shell:

```elixir

# v PREPARATIONS v

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

# v START DEMO HERE v

{:ok, raw_tx} = create_issue_transaction(asset, 5, alice, alice); {:ok, signature} = sign(raw_tx, alice_priv)
raw_tx <> " " <> signature

# try invalid operations using json rpc
# http --json localhost:4000 method=ubmit_transaction params:='{"transaction": ""}' jsonrpc=2.0 id=1
# http --json localhost:4000 method=submit_transaction params:='{"transactio": ""}' jsonrpc=2.0 id=1
# http --json localhost:4000 method=submit_transaction params:='{"transaction": ""}' jsonrpc=2.0 id=1
# paste transaction - fire twice to see handling of duplicates and waiting for commit, and return data
# http --json localhost:4000 method=submit_transaction params:='{"transaction": ""}' jsonrpc=2.0 id=1

# a send transaction, that will be signed off
{:ok, raw_tx} = create_send_transaction(asset, 5, alice, alice); {:ok, signature} = sign(raw_tx, alice_priv)
{:ok, tx_hash} = submit_transaction raw_tx <> " " <> signature

# see not signed off yet
tx(tx_hash)

# get height
{:ok, %{"height" => height}}  = tx(tx_hash)

# still won't be signed off
{:ok, raw_tx} = create_sign_off_transaction(height - 1, "abcd", alice); {:ok, signature} = sign(raw_tx, alice_priv)
submit_transaction raw_tx <> " " <> signature

tx(tx_hash)

# invalid sign-off
{:ok, raw_tx} = create_sign_off_transaction(height, "abcd", alice); {:ok, signature} = sign(raw_tx, alice_priv)
submit_transaction raw_tx <> " " <> signature

# this should successfully finalize the above send
{:ok, raw_tx} = create_sign_off_transaction(height - 1, "abcd", alice); {:ok, signature} = sign(raw_tx, alice_priv)
submit_transaction raw_tx <> " " <> signature


```
