## Finalized events and richer sign-off transaction logic. Reliable replay of events

1. Run a single node HonteD-Tendermint as usual (both apps!)
7. in `iex`/`wscat`/shell:

```elixir

# v PREPARATIONS v

alias HonteD.{Crypto, API, Transaction}

{:ok, alice_priv} = Crypto.generate_private_key; {:ok, alice_pub} = Crypto.generate_public_key alice_priv; {:ok, alice} = Crypto.generate_address alice_pub
{:ok, bob_priv} = Crypto.generate_private_key; {:ok, bob_pub} = Crypto.generate_public_key bob_priv; {:ok, bob} = Crypto.generate_address bob_pub

{:ok, raw_tx} = API.create_create_token_transaction(alice)
{:ok, hash} = raw_tx |> Transaction.sign(alice_priv) |> API.submit_commit()
{:ok, [asset]} = API.tokens_issued_by(alice)

{:ok, raw_tx} = API.create_issue_transaction(asset, 500, alice, alice)
raw_tx |> Transaction.sign(alice_priv) |> API.submit_commit()

# v START DEMO HERE v

# Part I SIGNATURES

# use alice_priv to load into MEW.com
# TODO (Pepesza)

# Part II ENCODING

# look at rlp encoding of an unsigned tx
{:ok, raw_tx} = API.create_send_transaction(asset, 5, alice, bob)

# again - signed tx
signed_tx = Transaction.sign(raw_tx, alice_priv)

# check that transaction works as usual
API.submit_commit(signed_tx)

# Part III trie in action
# TODO (PawelG)
# idea: run performance test and see that the throughput doesn't drop, which was previously caused by OJSON hashing

# Part IV Soft-slashing (removing from validator set)

# no public API to double-sign, we need to hack around

# get our validator's pub_key
pub_key =

# add following code to `abci.ex`
# TODO (Piotr)

recompile()
Genserver.call(HonteD.ABCI, {:double_sign, pub_key})

# see that consensus has stopped, because we slashed the only operator
