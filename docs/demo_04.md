## Finalized events and richer sign-off transaction logic. Reliable replay of events

1. Run a single node HonteD-Tendermint as usual (both apps!)
7. in `iex`/`wscat`/shell:

```elixir

# v PREPARATIONS v

import HonteD.API
import HonteD.Crypto

{:ok, alice_priv} = generate_private_key; {:ok, alice_pub} = generate_public_key alice_priv; {:ok, alice} = generate_address alice_pub
{:ok, bob_priv} = generate_private_key; {:ok, bob_pub} = generate_public_key bob_priv; {:ok, bob} = generate_address bob_pub
{:ok, ivan_priv} = generate_private_key; {:ok, ivan_pub} = generate_public_key ivan_priv; {:ok, ivan} = generate_address ivan_pub
{:ok, diane_priv} = generate_private_key; {:ok, diane_pub} = generate_public_key diane_priv; {:ok, diane} = generate_address diane_pub

{:ok, raw_tx} = create_create_token_transaction(ivan)
{:ok, hash} = raw_tx |> sign(ivan_priv) |> submit_commit()
{:ok, [asset]} = tokens_issued_by(ivan)

{:ok, raw_tx} = create_issue_transaction(asset, 500, alice, ivan)
raw_tx |> sign(ivan_priv) |> submit_commit()

# v START DEMO HERE v

# subscribe to bob's received
bob
# wscat --connect localhost:4004
# {"wsrpc": "1.0", "type": "rq", "method": "new_send_filter", "params": {"watched": ""}}

# send some transactions, that will be signed off later
{:ok, raw_tx} = create_send_transaction(asset, 5, alice, bob)
raw_tx |> sign(alice_priv) |> submit_commit()
{:ok, raw_tx} = create_send_transaction(asset, 5, alice, bob)
raw_tx |> sign(alice_priv) |> submit_commit()
{:ok, raw_tx} = create_send_transaction(asset, 5, alice, bob)
{:ok, %{tx_hash: tx_hash, committed_in: height}} = raw_tx |> sign(alice_priv) |> submit_commit()


# check Bob has received the events in wscat

# Now let's do some sign-offs!!!

# get height and block hash
{:ok, block_hash} = HonteD.API.Tools.get_block_hash(height - 1)

# Ivan can delegate signing to Diane and keep his issuing private key secure
# lets do that
{:ok, raw_tx} = create_allow_transaction(ivan, diane, "signoff", true)
raw_tx |> sign(ivan_priv) |> submit_commit()

# From now on, Diane can sign off on behalf of Ivan

# this should successfully finalize 2 of 3 above sends
{:ok, raw_tx} = create_sign_off_transaction(height - 1, block_hash, diane, ivan)
raw_tx |> sign(diane_priv) |> submit_commit()

# valid sign-off, but with wrong block_hash (puts all transactions of token into :committed_unknown state)
{:ok, raw_tx} = create_sign_off_transaction(height, "garbage", diane, ivan)
raw_tx |> sign(diane_priv) |> submit_commit()

# check no more finalized had been received

# check the corrupt state
tx(tx_hash)

# fix the broken sign-off
{:ok, new_block_hash} = HonteD.API.Tools.get_block_hash(height + 1)
{:ok, raw_tx} = create_sign_off_transaction(height + 1, new_block_hash, diane, ivan)
raw_tx |> sign(diane_priv) |> submit_commit()

# check the fixed state
tx(tx_hash)

# ==============================
# replays

# NOTE: client needs to remember the last `:committed` events until they are `:finalized`
# let's assume that everything goes down in height when the _second_ send got committed (see above)

# first, we restart node and wscat
# see the logs pass for the previous transactions while Tendermint replays
# NOTE: no events are subscribed to yet! This replay is *not our replay*, this is Tendermint stuff, forget it

bob = # bobs pub key from previous session

# re-do preparations (we've lost private keys :( )
{:ok, audrey_priv} = generate_private_key; {:ok, audrey_pub} = generate_public_key audrey_priv; {:ok, audrey} = generate_address audrey_pub
{:ok, imogen_priv} = generate_private_key; {:ok, imogen_pub} = generate_public_key imogen_priv; {:ok, imogen} = generate_address imogen_pub
{:ok, raw_tx} = create_create_token_transaction(imogen)
{:ok, hash} = raw_tx |> sign(imogen_priv) |> submit_commit()
{:ok, [asset]} = tokens_issued_by(imogen)

{:ok, raw_tx} = create_issue_transaction(asset, 500, audrey, imogen)
raw_tx |> sign(imogen_priv) |> submit_commit()

# PREPARATIONS DONE

# two events that could be "missed", because after reboot we haven't subscribed yet!!!
{:ok, raw_tx} = create_send_transaction(asset, 5, audrey, bob)
raw_tx |> sign(audrey_priv) |> submit_commit()
{:ok, raw_tx} = create_send_transaction(asset, 5, audrey, bob)
raw_tx |> sign(audrey_priv) |> submit_commit()

# subscribe to bob's received again
# NOTE: this time we take note of the height returned in the `new_send_filter` call
# wscat --connect localhost:4004
# {"wsrpc": "1.0", "type": "rq", "method": "new_send_filter", "params": {"watched": ""}}

# check that we can receive _new_ events just fine
{:ok, raw_tx} = create_send_transaction(asset, 5, audrey, bob)
raw_tx |> sign(audrey_priv) |> submit_commit()
{:ok, raw_tx} = create_send_transaction(asset, 5, audrey, bob)
raw_tx |> sign(audrey_priv) |> submit_commit()

# now grab the historic events 
# {"wsrpc": "1.0", "type": "rq", "method": "new_send_filter_history", "params": {"watched": "", "first": "", "last": ""}}

# use the committed but not finalized list to actively poll the finality of the remaining transactions
# NOTE: check both the transactions from the previous and current wscat session
# {"wsrpc": "1.0", "type": "rq", "method": "tx", "params": {"hash": ""}}

```
