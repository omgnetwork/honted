## Finalized events and richer sign-off transaction logic. Reliable replay of events

1. Run a single node HonteD-Tendermint as usual (both apps!)
7. in `iex`/`wscat`/shell:

```elixir

# v PREPARATIONS v

alias HonteD.{Crypto, API, Transaction}
require HonteD.ABCI.Records
alias HonteD.ABCI.Records

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

# get our validator's pub_key
# cat ~/.tendermint/priv_validator.json
pub_key =

# no public API to double-sign, we need to hack around
encoded_pub_key = <<1>> <> Base.decode16!(pub_key)
byzantine_validator = Records.evidence(pub_key: encoded_pub_key)

# add following code to `abci.ex` and comment usual `handle_call(request_begin_block)` out
        # FIXME: temporary code!!!
        def handle_call(request_begin_block(header: header(height: height)),
                        _from,
                        %HonteD.ABCI{consensus_state: consensus_state} = abci_app) do

          HonteD.ABCI.Events.notify(consensus_state, %HonteD.API.Events.NewBlock{height: height})
          {:reply, response_begin_block(), abci_app}
        end

        def handle_call({:double_sign, [evidence()] = byzantine_validators},
                        _from,
                        %HonteD.ABCI{byzantine_validators_cache: nil} = abci_app) do
          # push the new evidence to cache
          abci_app = %HonteD.ABCI{abci_app | byzantine_validators_cache: byzantine_validators}
          {:reply, {:yeeeeehaaaa_double_signed}, abci_app}
        end
        # FIXME: end temporary code!!!

recompile()
GenServer.call(HonteD.ABCI, {:double_sign, [byzantine_validator]})
# see that consensus has stopped, because we slashed the only operator
# NOTE: it crashes actually (bug?), probably because we're removing the only validator, but
#       we can see in the logs that the validator was removed
