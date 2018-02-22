defmodule HonteD.ABCITest do
  @moduledoc """
  **NOTE** this test will pretend to be Tendermint core
  """
  # NOTE: we can't enforce this here, because of the keyword-list-y form of create_x calls
  # credo:disable-for-this-file Credo.Check.Refactor.PipeChainStart

  use ExUnitFixtures
  use ExUnit.Case, async: true

  import HonteD.ABCI.TestHelpers
  import HonteD.ABCI.Records

  import HonteD.ABCI
  import HonteD.Transaction

  alias HonteD.Validator

  describe "info requests from tendermint" do
    @tag fixtures: [:empty_state]
    test "info about clean state", %{empty_state: state} do
      assert {:reply, response_info(last_block_height: 0), ^state} =
        handle_call(request_info(), nil, state)
    end
  end

  describe "checkTx" do
    @tag fixtures: [:issuer, :empty_state]
    test "builds upon state modified by dependent transaction",
      %{empty_state: state, issuer: issuer} do
      %{state: state} =
        create_create_token(nonce: 0, issuer: issuer.addr)
        |> encode_sign(issuer.priv) |> check_tx(state) |> success?
      asset = HonteD.Token.create_address(issuer.addr, 0)
      %{state: ^state} =
        create_issue(nonce: 0, asset: asset, amount: 1, dest: issuer.addr, issuer: issuer.addr)
        |> encode_sign(issuer.priv) |> check_tx(state) |> fail?(1, 'invalid_nonce')
      %{state: _} =
        create_issue(nonce: 1, asset: asset, amount: 1, dest: issuer.addr, issuer: issuer.addr)
        |> encode_sign(issuer.priv) |> check_tx(state) |> success?
    end
  end

  describe "commits" do
    @tag fixtures: [:issuer, :empty_state]
    test "hash from commits changes on state update", %{empty_state: state, issuer: issuer} do
      assert {:reply, {:ResponseCommit, 0, cleanhash, _}, ^state} = handle_call({:RequestCommit}, nil, state)

      %{state: state} =
        create_create_token(nonce: 0, issuer: issuer.addr)
        |> encode_sign(issuer.priv) |> deliver_tx(state) |> success?

      assert {:reply, {:ResponseCommit, 0, newhash, _}, _} = handle_call({:RequestCommit}, nil, state)
      assert newhash != cleanhash
    end

    @tag fixtures: [:issuer, :empty_state]
    test "commit overwrites local state with consensus state", %{empty_state: state, issuer: issuer} do
      %{state: updated_state} =
        create_create_token(nonce: 0, issuer: issuer.addr)
        |> encode_sign(issuer.priv) |> check_tx(state) |> success?
      assert updated_state != state

      # No deliverTx transactions were applied since last commit;
      # this should drop part of state related to checkTx, reverting
      # ABCI state to its initial value.
      assert {:reply, {:ResponseCommit, 0, _, _}, ^state} =
        handle_call({:RequestCommit}, nil, updated_state)
    end
  end

  describe "generic transaction checks" do
    @tag fixtures: [:empty_state]
    test "too large transactions throw", %{empty_state: state} do
      String.duplicate("a", 1024)
      |> ExRLP.encode()
      |> Base.encode16()
      |> deliver_tx(state) |> fail?(1, 'transaction_too_large') |> same?(state)
    end
  end

  describe "unhandled query clauses" do
    @tag fixtures: [:empty_state]
    test "queries to /store are verbosely unimplemented", %{empty_state: state} do
      # NOTE: this will naturally go away, if we decide to implement /store
      assert {:reply, {:ResponseQuery, 1, _, _, _, _, _, 'query to /store not implemented'}, ^state} =
        handle_call({:RequestQuery, "", '/store', 0, :false}, nil, state)
    end
  end

  describe "end block" do

    deffixture initial_validators do
      [%Validator{tendermint_address: tm_address(1), stake: 1},
       %Validator{tendermint_address: tm_address(2), stake: 1},
      ]
    end

    deffixture epoch_1_validators do
      [%Validator{tendermint_address: tm_address(2), stake: 1},
       %Validator{tendermint_address: tm_address(3), stake: 1},
       %Validator{tendermint_address: tm_address(4), stake: 1},
      ]
    end

    deffixture epoch_2_validators do
      [%Validator{tendermint_address: tm_address(2), stake: 10},
       %Validator{tendermint_address: tm_address(4), stake: 2},
       %Validator{tendermint_address: tm_address(5), stake: 1},
      ]
    end

    deffixture validators_diffs_1 do
      [validator(pub_key: pub_key(1), power: 0),
       validator(pub_key: pub_key(2), power: 1),
       validator(pub_key: pub_key(3), power: 1),
       validator(pub_key: pub_key(4), power: 1),
      ]
    end

    deffixture validators_diffs_2 do
      [validator(pub_key: pub_key(2), power: 10),
       validator(pub_key: pub_key(3), power: 0),
       validator(pub_key: pub_key(4), power: 2),
       validator(pub_key: pub_key(5), power: 1),
      ]
    end

    deffixture state_with_initial_validators(empty_state, initial_validators) do
      %{empty_state | initial_validators: initial_validators}
    end

    deffixture first_epoch_change_state(staking_state, state_with_initial_validators,
      epoch_1_validators, epoch_2_validators) do

      validators = %{
        1 => epoch_1_validators,
        2 => epoch_2_validators,
      }
      staking_state_with_validators = %{staking_state | validators: validators}
      {:noreply, state} =
        HonteD.ABCI.handle_cast({:set_staking_state, staking_state_with_validators},
                                state_with_initial_validators)
      state
    end

    @tag fixtures: [:empty_state]
    test "does not update validators and state when epoch has not changed", %{empty_state: state} do
      {:reply, response_end_block(validator_updates: diffs), ^state} =
        handle_call(request_end_block(), nil, state)
      assert diffs == []
    end

    @tag fixtures: [:first_epoch_change_state, :validators_diffs_1, :alice]
    test "updates set of validators for the first epoch",
    %{first_epoch_change_state: state, validators_diffs_1: expected_diffs, alice: alice} do

      %{state: state} =
        create_epoch_change(nonce: 0, sender: alice.addr, epoch_number: 1)
        |> encode_sign(alice.priv) |> deliver_tx(state)
      {:reply, response_end_block(validator_updates: actual_diffs), new_state} =
        handle_call(request_end_block(), nil, state)

      assert_same_elements(actual_diffs, expected_diffs)
      assert state.local_state == new_state.local_state
      assert state.consensus_state != new_state.consensus_state
    end

    @tag fixtures: [:first_epoch_change_state, :validators_diffs_2, :alice]
    test "updates set of validators when epoch changes",
    %{first_epoch_change_state: state, validators_diffs_2: expected_diffs, alice: alice} do

      # finalize prior (first) epoch change
      %{state: state} =
        create_epoch_change(nonce: 0, sender: alice.addr, epoch_number: 1)
        |> encode_sign(alice.priv) |> deliver_tx(state)
      {:reply, _, first_epoch_state} =
        handle_call(request_end_block(), nil, state)

      # continue to second epoch and test
      %{state: first_epoch_state} =
        create_epoch_change(nonce: 1, sender: alice.addr, epoch_number: 2)
        |> encode_sign(alice.priv) |> deliver_tx(first_epoch_state)

      {:reply, response_end_block(validator_updates: actual_diffs), second_epoch_state} =
        handle_call(request_end_block(), nil, first_epoch_state)

      assert_same_elements(actual_diffs, expected_diffs)
      assert second_epoch_state.local_state == first_epoch_state.local_state
      assert second_epoch_state.consensus_state != first_epoch_state.consensus_state
    end
  end

  describe "handling evidence of byzantine validators. " do
    @tag fixtures: [:state_with_initial_validators, :initial_validators]
    test "initial validator is removed during soft-slashing on evidence",
    %{state_with_initial_validators: state, initial_validators: validators} do
      [%HonteD.Validator{tendermint_address: pub_key} | _] = validators
      # FIXME: dry
      pub_key = <<1>> <> Base.decode16!(pub_key)
      {:reply, _, state_after_evidence} =
        handle_call(request_begin_block(header: header(height: 1),
                                        byzantine_validators: [evidence(pub_key: pub_key, height: 1)]),
                    nil,
                    state)

      assert {:reply, response_end_block(validator_updates: [validator(pub_key: ^pub_key, power: 0)]), _} =
        handle_call(request_end_block(), nil, state_after_evidence)
    end

    @tag fixtures: [:state_with_initial_validators, :initial_validators]
    test "evidence must be delivered to slash (flushing)",
    %{state_with_initial_validators: state, initial_validators: validators} do
      [%HonteD.Validator{tendermint_address: pub_key} | _] = validators
      pub_key = <<1>> <> Base.decode16!(pub_key)
      {:reply, _, state_after_evidence} =
        handle_call(request_begin_block(header: header(height: 1),
                                        byzantine_validators: [evidence(pub_key: pub_key, height: 1)]),
                    nil,
                    state)

      {:reply, _, slashed_state} =
        handle_call(request_end_block(), nil, state_after_evidence)
      {:reply, _, state_without_evidence} =
        handle_call(request_begin_block(header: header(height: 2)), nil, slashed_state)
      assert {:reply, response_end_block(validator_updates: []), _} =
        handle_call(request_end_block(), nil, state_without_evidence)
    end

    @tag fixtures: [:first_epoch_change_state, :epoch_1_validators, :alice]
    test "ordinary validators are removed during soft-slashing on evidence",
    %{first_epoch_change_state: state, epoch_1_validators: validators, alice: alice} do
      # finalize prior (first) epoch change
      # FIXME: dry this finalization - a state of being in epoch 1
      %{state: state} =
        create_epoch_change(nonce: 0, sender: alice.addr, epoch_number: 1)
        |> encode_sign(alice.priv) |> deliver_tx(state)
      {:reply, _, state} =
        handle_call(request_end_block(), nil, state)

      # slash em
      [%HonteD.Validator{tendermint_address: pub_key} | _] = validators
      pub_key = <<1>> <> Base.decode16!(pub_key)
      {:reply, _, state_after_evidence} =
        handle_call(request_begin_block(header: header(height: 1),
                                        byzantine_validators: [evidence(pub_key: pub_key, height: 1)]),
                    nil,
                    state)

      assert {:reply, response_end_block(validator_updates: [validator(pub_key: ^pub_key, power: 0)]), _} =
        handle_call(request_end_block(), nil, state_after_evidence)
    end

    @tag fixtures: [:first_epoch_change_state, :epoch_1_validators, :validators_diffs_2, :alice]
    test "epoch change overrides removing soft-slashd validators",
    %{first_epoch_change_state: state, epoch_1_validators: validators,
      validators_diffs_2: expected_diffs, alice: alice} do

      # finalize prior (first) epoch change
      %{state: state} =
        create_epoch_change(nonce: 0, sender: alice.addr, epoch_number: 1)
        |> encode_sign(alice.priv) |> deliver_tx(state)
      {:reply, _, state} =
        handle_call(request_end_block(), nil, state)

      # file evidence against a validator
      [%HonteD.Validator{tendermint_address: pub_key} | _] = validators
      pub_key = <<1>> <> Base.decode16!(pub_key)
      {:reply, _, state} =
        handle_call(request_begin_block(header: header(height: 1),
                                        byzantine_validators: [evidence(pub_key: pub_key, height: 1)]),
                    nil,
                    state)

      # at the same time epoch change happening
      %{state: state} =
        create_epoch_change(nonce: 1, sender: alice.addr, epoch_number: 2)
        |> encode_sign(alice.priv) |> deliver_tx(state)

      # the soft slashing didn't affect expected diffs arising from epoch change
      {:reply, response_end_block(validator_updates: actual_diffs), _} =
        handle_call(request_end_block(), nil, state)

      assert_same_elements(actual_diffs, expected_diffs)
    end

    @tag fixtures: [:first_epoch_change_state, :epoch_1_validators, :validators_diffs_2, :alice]
    test "epoch change resets prior removing soft-slashd validators",
    %{first_epoch_change_state: state, epoch_1_validators: validators,
      validators_diffs_2: expected_diffs, alice: alice} do

      # finalize prior (first) epoch change
      %{state: state} =
        create_epoch_change(nonce: 0, sender: alice.addr, epoch_number: 1)
        |> encode_sign(alice.priv) |> deliver_tx(state)
      {:reply, _, state} =
        handle_call(request_end_block(), nil, state)

      # file evidence against a validator AND FINALIZE IT (with sanity check)
      [%HonteD.Validator{tendermint_address: pub_key} | _] = validators
      pub_key = <<1>> <> Base.decode16!(pub_key)
      {:reply, _, state} =
        handle_call(request_begin_block(header: header(height: 1),
                                        byzantine_validators: [evidence(pub_key: pub_key, height: 1)]),
                    nil,
                    state)

      assert {:reply, response_end_block(validator_updates: [validator(pub_key: ^pub_key, power: 0)]), state} =
        handle_call(request_end_block(), nil, state)

      # later on epoch change happening, slashed validator should pop back in the set
      %{state: state} =
        create_epoch_change(nonce: 1, sender: alice.addr, epoch_number: 2)
        |> encode_sign(alice.priv) |> deliver_tx(state)

      {:reply, response_end_block(validator_updates: actual_diffs), _} =
        handle_call(request_end_block(), nil, state)

      assert_same_elements(actual_diffs, expected_diffs)
    end

    @tag fixtures: [:first_epoch_change_state, :epoch_1_validators, :alice]
    test "removing removed validators doesn't break",
    %{first_epoch_change_state: state, epoch_1_validators: validators, alice: alice} do
      # need to test this, evidence may arrive after a validator has become obsolete (epoch change)
      # this will happen e.g. when we only slash a not-yet-unlocked fee pot in the unbonding period
      # NOTE: we're assuming that removing absent validators is valid ABCI behavior

      # finalize prior (first) epoch change
      %{state: state} =
        create_epoch_change(nonce: 0, sender: alice.addr, epoch_number: 1)
        |> encode_sign(alice.priv) |> deliver_tx(state)
      {:reply, _, state} =
        handle_call(request_end_block(), nil, state)

      # validator who misbehaves later, let's pick the second one
      [_validator1, %HonteD.Validator{tendermint_address: pub_key} | _] = validators
      pub_key = <<1>> <> Base.decode16!(pub_key)

      # finalize second epoch change, this removes one of the validators, who will misbehave later
      %{state: state} =
        create_epoch_change(nonce: 1, sender: alice.addr, epoch_number: 2)
        |> encode_sign(alice.priv) |> deliver_tx(state)
      {:reply, response_end_block(validator_updates: actual_diffs), state} =
        handle_call(request_end_block(), nil, state)

      # let's sanity check, that we actually did remove that misbehaving validator on epoch change
      assert Enum.member?(actual_diffs, validator(pub_key: pub_key, power: 0))

      # file evidence, should return a no-op-ing validator set update on absent validator
      {:reply, _, state} =
        handle_call(request_begin_block(header: header(height: 1),
                                        byzantine_validators: [evidence(pub_key: pub_key, height: 1)]),
                    nil,
                    state)

      # NOTE: we don't test here the other effect of soft-slashing, that is depriving of accumulated earnings
      assert {:reply, response_end_block(validator_updates: [validator(pub_key: ^pub_key, power: 0)]), _} =
        handle_call(request_end_block(), nil, state)
    end
  end

  describe "init chain request" do
    @tag fixtures: [:empty_state]
    test "sets initial validators", %{empty_state: state} do
      {stake, pub_key} = {1, pub_key(1)}
      {:reply, _, state} =
        handle_call(request_init_chain(validators: [validator(power: stake, pub_key: pub_key)]),
                    nil, state)
      assert state.initial_validators == [%Validator{stake: stake, tendermint_address: tm_address(1)}]
    end
  end

end
