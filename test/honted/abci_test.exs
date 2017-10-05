defmodule HonteD.ABCITest do
  @moduledoc """
  **NOTE** this test will pretend to be Tendermint core
  """
  use ExUnit.Case
  doctest HonteD

  import HonteD.ABCI

  # FIXME test everything correctly in all tests, many conditions skipped

  setup do
    {:ok, state} = HonteD.ABCI.init(:ok)
    {:ok, state: state}
  end

  test "info about clean state", %{state: state} do
    assert {:reply, {:ResponseInfo, 'arbitrary information', 'version info', 0, ''}, ^state} = handle_call({:RequestInfo}, nil, state)
  end

  test "checking issue transactions",  %{state: state} do

    assert {:reply, {:ResponseCheckTx, 0, 'answer check tx', 'log check tx'}, ^state} =
      handle_call({:RequestCheckTx, "ISSUE asset 5 alice"}, nil, state)

    # malformed
    assert {:reply, {:ResponseCheckTx, 1, 'answer check tx', 'malformed_transaction'}, ^state} =
      handle_call({:RequestCheckTx, "ISSU asset 5 alice"}, nil, state)
  end

  test "malformed send transactions", %{state: state} do

    {:reply, _, state} =
      handle_call({:RequestDeliverTx, "ISSUE asset 5 alice"}, nil, state)

    # malformed
    assert {:reply, {:ResponseCheckTx, 1, 'answer check tx', 'malformed_transaction'}, ^state} =
      handle_call({:RequestCheckTx, "0 SEN asset 5 alice bob"}, nil, state)
  end

  test "querying nonces", %{state: state} do

    {:reply, _, state} =
      handle_call({:RequestDeliverTx, "ISSUE asset 5 alice"}, nil, state)

    assert {:reply, {:ResponseQuery, 0, 0, 'nonces/alice', '0', 'no proof', _, 'query log'}, ^state} =
      handle_call({:RequestQuery, "", '/nonces/alice', 0, false}, nil, state)

    {:reply, _, state} =
      handle_call({:RequestDeliverTx, "0 SEND asset 5 alice bob"}, nil, state)

    assert {:reply, {:ResponseQuery, 0, 0, 'nonces/bob', '0', 'no proof', _, 'query log'}, ^state} =
      handle_call({:RequestQuery, "", '/nonces/bob', 0, false}, nil, state)

    assert {:reply, {:ResponseQuery, 0, 0, 'nonces/alice', '1', 'no proof', _, 'query log'}, ^state} =
      handle_call({:RequestQuery, "", '/nonces/alice', 0, false}, nil, state)
  end

  test "checking nonces", %{state: state} do

    {:reply, _, state} =
      handle_call({:RequestDeliverTx, "ISSUE asset 5 alice"}, nil, state)
    assert {:reply, {:ResponseCheckTx, 1, 'answer check tx', 'error'}, ^state} =
      handle_call({:RequestCheckTx, "1 SEND asset 1 alice bob"}, nil, state)
      
    {:reply, _, state} =
      handle_call({:RequestDeliverTx, "0 SEND asset 1 alice bob"}, nil, state)

    assert {:reply, {:ResponseCheckTx, 1, 'answer check tx', 'error'}, ^state} =
      handle_call({:RequestCheckTx, "0 SEND asset 1 alice bob"}, nil, state)
    assert {:reply, {:ResponseCheckTx, 1, 'answer check tx', 'error'}, ^state} =
      handle_call({:RequestCheckTx, "2 SEND asset 1 alice bob"}, nil, state)
    assert {:reply, {:ResponseCheckTx, 0, _answer, _log}, ^state} =
      handle_call({:RequestCheckTx, "1 SEND asset 1 alice bob"}, nil, state)
  end

  test "hash from commits changes on state update", %{state: state} do
    assert {:reply, {:ResponseCommit, 0, cleanhash, _}, ^state} = 
      handle_call({:RequestCommit}, nil, state)
    
    {:reply, _, state} =
      handle_call({:RequestDeliverTx, "ISSUE asset 5 alice"}, nil, state)
      
    assert {:reply, {:ResponseCommit, 0, newhash, _}, ^state} = 
      handle_call({:RequestCommit}, nil, state)
      
    assert newhash != cleanhash
  end
  
  test "send transactions logic", %{state: state} do
    {:reply, _, state} =
      handle_call({:RequestDeliverTx, "ISSUE asset 5 alice"}, nil, state)
      
    # correct transfer
    assert {:reply, _, state} =
      handle_call({:RequestDeliverTx, "0 SEND asset 1 alice bob"}, nil, state)
    assert {:reply, {:ResponseQuery, 0, 0, _, '1', 'no proof', _, _log}, ^state} =
      handle_call({:RequestQuery, "", '/accounts/asset/bob', 0, false}, nil, state)
    assert {:reply, {:ResponseQuery, 0, 0, _, '4', 'no proof', _, _log}, ^state} =
      handle_call({:RequestQuery, "", '/accounts/asset/alice', 0, false}, nil, state)
      
    # insufficient funds, state unchanged
    # FIXME: handle answer/error in checktx
    # FIXME: handle and test other returns properly
    assert {:reply, {:ResponseCheckTx, 1, _answer, 'error'}, ^state} =
      handle_call({:RequestCheckTx, "1 SEND asset 5 alice bob"}, nil, state)
    # negative/zero amount
    assert {:reply, {:ResponseCheckTx, 1, _answer, 'error'}, ^state} =
      handle_call({:RequestCheckTx, "1 SEND asset -1 alice bob"}, nil, state)
    assert {:reply, {:ResponseCheckTx, 1, _answer, 'error'}, ^state} =
      handle_call({:RequestCheckTx, "1 SEND asset 0 alice bob"}, nil, state)
      
    # unknown sender
    assert {:reply, {:ResponseCheckTx, 1, 'answer check tx', 'error'}, ^state} =
      handle_call({:RequestCheckTx, "1 SEND asset 5 carol bob"}, nil, state)
      
    # sanity
    assert {:reply, {:ResponseCheckTx, 0, _answer, _log}, ^state} =
      handle_call({:RequestCheckTx, "1 SEND asset 4 alice bob"}, nil, state)
    assert {:reply, {:ResponseDeliverTx, 0, _answer, _log}, _} =
      handle_call({:RequestDeliverTx, "1 SEND asset 4 alice bob"}, nil, state)

  end

end
