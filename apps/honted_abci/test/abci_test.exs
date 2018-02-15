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
        |> sign(issuer.priv) |> check_tx(state) |> success?
      asset = HonteD.Token.create_address(issuer.addr, 0)
      %{state: ^state} =
        create_issue(nonce: 0, asset: asset, amount: 1, dest: issuer.addr, issuer: issuer.addr)
        |> sign(issuer.priv) |> check_tx(state) |> fail?(1, 'invalid_nonce')
      %{state: _} =
        create_issue(nonce: 1, asset: asset, amount: 1, dest: issuer.addr, issuer: issuer.addr)
        |> sign(issuer.priv) |> check_tx(state) |> success?
    end
  end

  describe "commits" do
    @tag fixtures: [:issuer, :empty_state]
    test "hash from commits changes on state update", %{empty_state: state, issuer: issuer} do
      assert {:reply, {:ResponseCommit, 0, cleanhash, _}, ^state} = handle_call({:RequestCommit}, nil, state)

      %{state: state} =
        create_create_token(nonce: 0, issuer: issuer.addr)
        |> sign(issuer.priv) |> deliver_tx(state) |> success?

      assert {:reply, {:ResponseCommit, 0, newhash, _}, _} = handle_call({:RequestCommit}, nil, state)
      assert newhash != cleanhash
    end

    @tag fixtures: [:issuer, :empty_state]
    test "commit overwrites local state with consensus state", %{empty_state: state, issuer: issuer} do
      %{state: updated_state} =
        create_create_token(nonce: 0, issuer: issuer.addr)
        |> sign(issuer.priv) |> check_tx(state) |> success?
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
      String.duplicate("a", 512)
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

    deffixture first_epoch_change_state(alice, empty_state, staking_state,
     initial_validators, epoch_1_validators, epoch_2_validators) do
      validators = %{
        1 => epoch_1_validators,
        2 => epoch_2_validators,
      }
      staking_state_with_validators = %{staking_state | validators: validators}

      %{state: state} =
        create_epoch_change(nonce: 0, sender: alice.addr, epoch_number: 1)
        |> sign(alice.priv) |> deliver_tx(empty_state)
      state_with_inital_validators = %{state | initial_validators: initial_validators}
      {:noreply, state} =
        HonteD.ABCI.handle_cast({:set_staking_state, staking_state_with_validators},
          state_with_inital_validators)
      state
    end

    @tag fixtures: [:empty_state]
    test "does not update validators and state when epoch has not changed", %{empty_state: state} do
      {:reply, response_end_block(validator_updates: diffs), ^state} =
        handle_call(request_end_block(), nil, state)
      assert diffs == []
    end

    @tag fixtures: [:first_epoch_change_state, :validators_diffs_1]
    test "updates set of validators for the first epoch",
    %{first_epoch_change_state: state, validators_diffs_1: expected_diffs} do
      {:reply, response_end_block(validator_updates: actual_diffs), new_state} =
        handle_call(request_end_block(), nil, state)

      assert_same_elements(actual_diffs, expected_diffs)
      assert state.local_state == new_state.local_state
      assert state.consensus_state != new_state.consensus_state
    end

    @tag fixtures: [:first_epoch_change_state, :validators_diffs_2, :alice]
    test "updates set of validators when epoch changes",
    %{first_epoch_change_state: state, validators_diffs_2: expected_diffs, alice: alice} do
      {:reply, _, first_epoch_state} =
        handle_call(request_end_block(), nil, state)

      %{state: first_epoch_state} =
        create_epoch_change(nonce: 1, sender: alice.addr, epoch_number: 2)
        |> sign(alice.priv) |> deliver_tx(first_epoch_state)

      {:reply, response_end_block(validator_updates: actual_diffs), second_epoch_state} =
        handle_call(request_end_block(), nil, first_epoch_state)

      assert_same_elements(actual_diffs, expected_diffs)
      assert second_epoch_state.local_state == first_epoch_state.local_state
      assert second_epoch_state.consensus_state != first_epoch_state.consensus_state
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
