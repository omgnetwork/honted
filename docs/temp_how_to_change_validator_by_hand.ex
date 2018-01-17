
# howto:
# run tendermint node
# run iex -s mix
# copy paste the following into prompt
# consensus should stop
# FIXME: remove this file after using
# FIXME: fix tests

alias HonteD.{Crypto, API}

fake_tendermint_validator = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

validators = %{1 => [%HonteD.Validator{stake: 1, tendermint_address: fake_tendermint_validator}]}


staking = %HonteD.Staking{
        ethereum_block_height: 21,
        start_block: 0,
        epoch_length: 20,
        maturity_margin: 1,
        validators: validators,
}


GenServer.cast(HonteD.ABCI, {:set_staking_state, staking})


{:ok, alice_priv} = Crypto.generate_private_key; {:ok, alice_pub} = Crypto.generate_public_key alice_priv
{:ok, alice} = Crypto.generate_address alice_pub


{:ok, raw_tx} = API.create_epoch_change_transaction(alice, 1); {:ok, signature} = Crypto.sign(raw_tx, alice_priv)
{:ok, _} = API.submit_transaction raw_tx <> " " <> signature
