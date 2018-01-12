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
      |> check_tx(state) |> fail?(1, 'transaction_too_large') |> same?(state)
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

  describe "end block," do
    @tag fixtures: [:empty_state]
    test "does not update validators and state when epoch has not changed", %{empty_state: state} do
      assert {:reply, response_end_block(diffs: []), ^state} =
        handle_call(request_end_block(), nil, state)
    end

    @tag fixtures: [:first_epoch_change_state, :validators_diffs_1]
    test "updates set of validators for the first epoch",
    %{first_epoch_change_state: state, validators_diffs_1: diffs} do
      assert {:reply, response_end_block(diffs: diffs), _} =
        handle_call(request_end_block(), nil, state)
    end

    @tag fixtures: [:second_epoch_change_state, :validators_diffs_2]
    test "updates set of validators when epoch changes",
    %{second_epoch_change_state: state, validators_diffs_2: diffs} do
      assert {:reply, response_end_block(diffs: diffs), _} =
        handle_call(request_end_block(), nil, state)
    end
  end

end
