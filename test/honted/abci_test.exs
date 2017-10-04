defmodule HonteD.ABCITest do
  @moduledoc """
  **NOTE** this test will pretend to be Tendermint core
  """
  use ExUnit.Case
  doctest HonteD

  import HonteD.ABCI

  # FIXME test everything correctly in all tests, many conditions skipped
  # FIXME DRY setups

  test "info about clean state" do
    {:ok, state} = HonteD.ABCI.init(:ok)
    {:reply, {:ResponseInfo, '','',0,''}, ^state} = handle_call({:RequestInfo}, nil, state)
  end

  test "checking issue transactions" do
    {:ok, state} = HonteD.ABCI.init(:ok)

    assert {:reply, {:ResponseCheckTx, 0, 'answer check tx', 'log check tx'}, ^state} =
      handle_call({:RequestCheckTx, "ISSUE asset 5 alice"}, nil, state)

    # malformed
    assert {:reply, {:ResponseCheckTx, 1, 'answer check tx', 'malformed_transaction'}, ^state} =
      handle_call({:RequestCheckTx, "ISSU asset 5 alice"}, nil, state)
  end

  test "checking send transactions" do
    {:ok, state} = HonteD.ABCI.init(:ok)

    {:reply, _, state} =
      handle_call({:RequestDeliverTx, "ISSUE asset 5 alice"}, nil, state)

    assert {:reply, {:ResponseCheckTx, 0, 'answer check tx', 'log check tx'}, ^state} =
      handle_call({:RequestCheckTx, "SEND asset 5 alice bob"}, nil, state)

    # malformed
    assert {:reply, {:ResponseCheckTx, 1, 'answer check tx', 'malformed_transaction'}, ^state} =
      handle_call({:RequestCheckTx, "SEN asset 5 alice bob"}, nil, state)

    # invalid
    assert {:reply, {:ResponseCheckTx, 1, 'answer check tx', 'error'}, ^state} =
      handle_call({:RequestCheckTx, "SEND asset 5 carol bob"}, nil, state)

  end



end
