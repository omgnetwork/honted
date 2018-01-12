defmodule HonteD.ABCI.Fixtures do
  # NOTE: we can't enforce this here, because of the keyword-list-y form of create_x calls
  # credo:disable-for-this-file Credo.Check.Refactor.PipeChainStart

  use ExUnitFixtures.FixtureModule

  alias HonteD.Validator

  import HonteD.Transaction
  import HonteD.ABCI.TestHelpers

  deffixture staking_state do
    %HonteD.Staking{
      ethereum_block_height: 10,
      start_block: 0,
      epoch_length: 2,
      maturity_margin: 1
    }
  end

  deffixture empty_state(staking_state) do
    {:ok, state} = HonteD.ABCI.init(:ok, staking_state)
    state
  end

  deffixture entities do
    %{
      alice: generate_entity(),
      bob: generate_entity(),
      issuer: generate_entity(),
      issuer2: generate_entity(),
      carol: generate_entity(),
    }
  end

  deffixture alice(entities), do: entities.alice
  deffixture bob(entities), do: entities.bob
  deffixture carol(entities), do: entities.carol
  deffixture issuer(entities), do: entities.issuer
  deffixture issuer2(entities), do: entities.issuer2

  deffixture asset(state_with_token, issuer) do
    %{code: 0, value: [asset]} = query(state_with_token, '/issuers/#{issuer.addr}')
    asset
  end

  deffixture asset2(state_bob_has_tokens2, issuer2) do
    %{code: 0, value: [asset]} = query(state_bob_has_tokens2, '/issuers/#{issuer2.addr}')
    asset
  end

  deffixture state_with_token(empty_state, issuer) do
    %{code: 0, state: state} =
      create_create_token(nonce: 0, issuer: issuer.addr) |> sign(issuer.priv) |> deliver_tx(empty_state)
    %{state: state} = commit(state)
    state
  end

  deffixture state_alice_has_tokens(state_with_token, alice, issuer, asset) do
    %{code: 0, state: state} =
      create_issue(nonce: 1, asset: asset, amount: 5, dest: alice.addr, issuer: issuer.addr)
      |> sign(issuer.priv) |> deliver_tx(state_with_token)
    %{state: state} = commit(state)
    state
  end

  deffixture state_bob_has_tokens2(state_alice_has_tokens, bob, issuer2, asset2) do
    %{code: 0, state: state} =
      create_create_token(nonce: 0, issuer: issuer2.addr) |> sign(issuer2.priv)
      |> deliver_tx(state_alice_has_tokens)
    %{code: 0, state: state} =
      create_issue(nonce: 1, asset: asset2, amount: 5, dest: bob.addr, issuer: issuer2.addr)
      |> sign(issuer2.priv) |> deliver_tx(state)
    %{state: state} = commit(state)
    state
  end

  deffixture some_block_hash do
    "ABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCD"
  end

  deffixture state_no_epoch_change(empty_state, staking_state) do
    staking_state_no_epoch_change = %{staking_state | ethereum_block_height: 0}
    {:noreply, state} =
      HonteD.ABCI.handle_cast({:set_staking_state, staking_state_no_epoch_change}, self(), empty_state)
    state
  end

  deffixture initial_validators do
    [Validator.validator({1, "tm_addr_1", "eth_addr_1"}),
     Validator.validator({10, "tm_addr_2", "eth_addr_2"}),
    ]
  end

  deffixture epoch_1_validators do
    [Validator.validator({1, "tm_addr_2", "eth_addr_2"}),
     Validator.validator({1, "tm_addr_3", "eth_addr_3"}),
     Validator.validator({2, "tm_addr_4", "eth_addr_4"}),
    ]
  end

  deffixture epoch_2_validators do
    [Validator.validator({10, "tm_addr_2", "eth_addr_2"}),
     Validator.validator({2, "tm_addr_4", "eth_addr_4"}),
     Validator.validator({1, "tm_addr_5", "eth_addr_5"}),
    ]
  end

  deffixture validators_diffs_1 do
    [{0, "tm_addr_1"},
     {1, "tm_addr_2"},
     {1, "tm_addr_3"},
     {2, "tm_addr_4"},
    ]
  end

  deffixture validators_diffs_2 do
    [{10, "tm_addr_1"},
     {2, "tm_addr_3"},
     {1, "tm_addr_4"},
     {0, "tm_addr_2"},
    ]
  end

  deffixture first_epoch_change_state(alice, empty_state, staking_state,
   initial_validators, epoch_1_validators) do
    validators = %{
      1 => epoch_1_validators,
    }
    staking_state_with_validators = %{staking_state | validators: validators}

    %{state: state} =
      create_epoch_change(nonce: 0, sender: alice.addr, epoch_number: 1)
      |> sign(alice.priv) |> check_tx(empty_state)
    state_with_inital_validators = %{state | initial_validators: initial_validators}
    {:noreply, state} =
      HonteD.ABCI.handle_cast({:set_staking_state, staking_state_with_validators},
        self(), state_with_inital_validators)
    state
  end

  deffixture second_epoch_change_state(alice, first_epoch_change_state, staking_state,
   epoch_1_validators, epoch_2_validators) do
     validators = %{
       1 => epoch_1_validators,
       2 => epoch_2_validators
     }
     %{state: state} =
       create_epoch_change(nonce: 0, sender: alice.addr, epoch_number: 1)
       |> sign(alice.priv) |> check_tx(first_epoch_change_state)
    staking_state_with_validators = %{staking_state | validators: validators}
    {:noreply, state} =
      HonteD.ABCI.handle_cast({:set_staking_state, staking_state_with_validators},
        self(), state)
    state
  end

end
