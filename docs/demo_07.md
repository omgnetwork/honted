## Staking and validator set changes (+performance test bonus)

(**NOTE** we need two tendermint validator nodes, so:)

1. Prepare the 2-node setup as follows:
        tendermint init --home ~/.tendermint1
        cp -r ~/.tendermint1 ~/.tendermint2
        tendermint gen_validator > ~/.tendermint2/priv_validator.json

        cp config/config.exs config/config1.exs
        cp config/config.exs config/config2.exs
2. Run and keep running somewhere
        geth --dev --rpc

2. in a separate shell deploy the contracts (shell: `iex -S mix run --no-start`) then leave `iex`
        {:ok, token, staking} = HonteD.Integration.Contract.deploy(30, 10, 1)
3. Do the following and run some commands:

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

        # modify both config/config2.exs and config/config1.exs with the staking contract address and flag
        #
        config :honted_eth,
          staking_contract_address:
        config :honted_eth,
          enabled: true
        #
        # at the bottom

        iex -S mix run --config config/config1.exs

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

7. in the second of the `iex`es:

```elixir

alias HonteD.{Crypto, API, Integration, Eth}

{:ok, alice_priv} = Crypto.generate_private_key; {:ok, alice_pub} = Crypto.generate_public_key alice_priv
{:ok, alice} = Crypto.generate_address alice_pub

{:ok, token, staking} =



{:ok, [alice_ethereum_address | _]} = Ethereumex.HttpClient.eth_accounts()

{:ok, _} = Integration.Contract.mint_omg(token, alice_ethereum_address, 100)

# v DEMO START HERE v

# first acknowledge in logs of the second node that the validator in commits coincides with validator1's address
# stored in priv_validator.json in ~/.tendermint1
# in logs look for something like:
# Precommits: Vote{0:<!!!  head of validator address  !!!> 1840/00/2(Precommit) AE1BD50FC3B3 {/5CF74AD8C951.../}}


# next do steps to change that to the other validator as follows:

# get the validator pubkey from the priv_validator.json in ~/.tendermint2
new_validator_pubkey =

{:ok, _} = Integration.Contract.approve(token, alice_ethereum_address, staking, 100)
{:ok, _} = Integration.Contract.deposit(staking, alice_ethereum_address, 100)
{:ok, _} = Integration.Contract.join(staking, alice_ethereum_address, new_validator_pubkey)

{:ok, next} = Eth.Contract.get_next_epoch_block_number(staking)
HonteD.Integration.WaitFor.eth_block_height(next + 1, true, 10_000)


# NOTE: here one should probably double check, if one made it within the join-eject window for epoch 1

{:ok, raw_tx} = API.create_epoch_change_transaction(alice, 1)
raw_tx |> Transaction.sign(alice_priv) |> API.submit_commit()

# see in the logs that the validator has changed to one from ~/.tendermint2/priv_validator.json, as above

# ALICE is validating now, and BOB observes that!
```
