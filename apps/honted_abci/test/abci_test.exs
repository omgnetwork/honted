defmodule HonteD.ABCITest do
  @moduledoc """
  **NOTE** this test will pretend to be Tendermint core
  """
  # NOTE: we can't enforce this here, because of the keyword-list-y form of create_x calls
  # credo:disable-for-this-file Credo.Check.Refactor.PipeChainStart

  use ExUnitFixtures
  use ExUnit.Case, async: true

  import HonteD.ABCI.TestHelpers

  import HonteD.ABCI
  import HonteD.Transaction

  describe "info requests from tendermint" do
    @tag fixtures: [:empty_state]
    test "info about clean state", %{empty_state: state} do
      assert {:reply, {:ResponseInfo, 'arbitrary information', 'version info', 0, ''}, ^state} =
        handle_call({:RequestInfo}, nil, state)
    end
  end

  describe "commits" do
    @tag fixtures: [:issuer, :empty_state]
    test "hash from commits changes on state update", %{empty_state: state, issuer: issuer} do
      assert {:reply, {:ResponseCommit, 0, cleanhash, _}, ^state} = handle_call({:RequestCommit}, nil, state)

      %{state: state} =
        create_create_token(nonce: 0, issuer: issuer.addr)
        |> sign(issuer.priv) |> deliver_tx(state) |> success?

      assert {:reply, {:ResponseCommit, 0, newhash, _}, ^state} =  handle_call({:RequestCommit}, nil, state)
      assert newhash != cleanhash
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
        handle_call({:RequestQuery, '', '/store', 0, :false}, nil, state)
    end
  end
end
