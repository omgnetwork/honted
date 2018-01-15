## Staking and validator set changes (+performance test bonus)

(**NOTE** we need to tendermint validator nodes, so:)

1. Prepare the 2-node setup as follows:
        tendermint init --home ~/.tendermint1
        cp -r ~/.tendermint1 ~/.tendermint2
        tendermint gen_validator > ~/.tendermint2/priv_validator.json

        cp config/config.exs config/config2.exs
        # modify config/config2.exs according to ports below, by adding
        #
        config :honted_abci,
          abci_port: 46_668
        config :honted_api,
          tendermint_rpc_port: 46_667
        config :honted_jsonrpc,
          honted_api_rpc_port: 4010
        config :honted_ws,
          honted_api_ws_port: 4014
        #
        # at the bottom

        iex -S mix

        # elsewhere
        tendermint node --home ~/.tendermint1

        # elsewhere
        iex -S mix run --config config/config2.exs

        # elsewhere
        tendermint node --proxy_app tcp://127.0.0.1:46668 \
                --rpc.laddr tcp://0.0.0.0:46667 \
                --p2p.laddr tcp://0.0.0.0:46666 \
                --p2p.seeds 127.0.0.1:46656 \
                --home ~/.tendermint2 \
                --log_level "*:info"   #* <- this hash-asterisk is to fix an issue with markdown rendering

7. in first of the `iex`es:

```elixir

# v PREPARATIONS v

import HonteD

{:ok, alice_priv} = Crypto.generate_private_key; {:ok, alice_pub} = Crypto.generate_public_key alice_priv
{:ok, alice} = Crypto.generate_address alice_pub

{:ok, token_address, staking_address} = Eth.Contract.deploy_dev(100, 10, 1)

alice_ethereum_address = :todo
Eth.Contract.mint_omg(token_address, alice_ethereum_address, 100)

# v DEMO START HERE v

# first acknowledge in logs of the second node that the validator in commits coincides with validator1's address
# stored in priv_validator.json in ~/.tendermint1
# in logs look for something like:
# Precommits: Vote{0:<!!!  head of validator address  !!!> 1840/00/2(Precommit) AE1BD50FC3B3 {/5CF74AD8C951.../}}


# next do steps to change that to the other validator as follows:

# get the validator pubkey from the priv_validator.json in ~/.tendermint2
new_validator_pubkey = :todo

Eth.Contract.approve(token_address, staking_address, 100)
Eth.Contract.deposit(staking_address, 100)
Eth.Contract.join(staking_address, new_validator_pubkey)

# NOTE: here one should probably double check, if one made it within the join-eject window for epoch 1

{:ok, raw_tx} = create_epoch_change_transaction(alice, 1); {:ok, signature} = sign(raw_tx, alice_priv)
{:ok, _} = submit_commit raw_tx <> " " <> signature

# see in the logs that the validator has changed to one from ~/.tendermint2/priv_validator.json, as above

```
