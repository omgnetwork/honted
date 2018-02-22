defmodule HonteD.ABCI.TestHelpers do
  @moduledoc """
  Various shared functions used in ABCI tests
  """

  import ExUnit.Assertions
  import HonteD.ABCI

  ## HELPER functions
  def generate_entity do
    {:ok, priv} = HonteD.Crypto.generate_private_key
    {:ok, pub} = HonteD.Crypto.generate_public_key(priv)
    {:ok, addr} = HonteD.Crypto.generate_address(pub)
    %{priv: priv, addr: addr}
  end

  def encode(tx) when is_map(tx) do
    tx
    |> HonteD.TxCodec.encode()
    |> Base.encode16()
  end

  # TxCodec.encode makes it hard to create malformed transactions;
  # We need malformed transactions to check if we are processing
  # correctly junk that comes from the network.
  @spec sign_malformed_tx(tuple, binary) :: binary
  def sign_malformed_tx(tuple, priv) when is_tuple(tuple) do
    sig =
      tuple
      |> Tuple.to_list()
      |> ExRLP.encode()
      |> HonteD.Crypto.signature(priv)
    tuple
    |> Tuple.append(sig)
    |> Tuple.to_list()
    |> ExRLP.encode()
    |> Base.encode16()
  end

  def encode_sign({:ok, raw_tx}, priv_key), do: encode_sign(raw_tx, priv_key)
  def encode_sign(raw_tx, priv_key) when is_map(raw_tx) do
    raw_tx
    |> encode()
    |> HonteD.Transaction.sign(priv_key)
  end

  def misplaced_sign(tx1, tx2, priv) do
    sig =
      tx1
      |> HonteD.TxCodec.encode()
      |> HonteD.Crypto.signature(priv)
    tx2
    |> HonteD.Transaction.with_signature(sig)
    |> encode()
  end

  @doc """
  Utility to deliver a transaction and do basic checks

  It also checks the assumption, that considering a prior commit, deliver_tx would behave on par with check_tx
  for all transactions

  NOTE: In case transaction validity starts to differ between deliver and check, this fails and needs to be reworked
  """
  def deliver_tx(signed_tx, state) do
    %{state: checkable_state} = commit(state)

    deliver_result = do_tx(:RequestDeliverTx, :ResponseDeliverTx, signed_tx, state)
    check_result = do_tx(:RequestCheckTx, :ResponseCheckTx, signed_tx, checkable_state)
    check_deliver_tx_parity(deliver_result, check_result)
    deliver_result
  end

  @doc """
  Utility to check a transaction and to do basic checks. Notice that his doesn't do the parity check,
  since DeliverTx has side effects (event message)
  """
  def check_tx(signed_tx, state) do
    do_tx(:RequestCheckTx, :ResponseCheckTx, signed_tx, state)
  end

  def do_tx(request_atom, response_atom, {:ok, signed_tx}, state) do
    do_tx(request_atom, response_atom, signed_tx, state)
  end
  def do_tx(request_atom, response_atom, hex_encoded_tx, abci_app) do
    # RLP is our wire protocol:
    signed_tx = Base.decode16!(hex_encoded_tx)
    assert {:reply, reply, abci_app} = handle_call({request_atom, signed_tx}, nil, abci_app)
    status = check_response(response_atom, reply)
    %{status | state: abci_app}
  end

  defp check_response(:ResponseCheckTx, reply) do
    assert {:ResponseCheckTx, code, data, log, gas, fee} = reply
    %{state: nil, code: code, data: data, log: log, gas: gas, fee: fee, tags: nil}
  end
  defp check_response(response_atom, reply) do
    assert {^response_atom, code, data, log, tags} = reply
    %{state: nil, code: code, data: data, log: log, gas: nil, fee: nil, tags: tags}
  end

  defp check_deliver_tx_parity(deliver_result, check_result) do
    assert deliver_result.code == check_result.code
    assert deliver_result.data == check_result.data
    assert deliver_result.log == check_result.log
    # NOTE: breaching of the "test via public API" rule, but this is the easiest way of testing behavior:
    #       "checktx and delivertx share the same state-modifying semantics"
    #       Rethink, in case this proves cumbersome
    assert deliver_result.state.consensus_state == check_result.state.local_state
  end

  def commit(%{state: state}), do: commit(state)
  def commit(state) do
    assert {:reply, {:ResponseCommit, 0, data, log}, state} =
      handle_call({:RequestCommit}, nil, state)
    %{code: 0, data: data, log: log, state: state}
  end

  def success?(response) do
    assert %{code: 0, data: "", log: ''} = response
    response
  end

  def fail?(response, expected_code, expected_log) do
    assert %{code: ^expected_code, data: "", log: ^expected_log} = response
    response
  end

  def query(state, key) do
    assert {:reply, {:ResponseQuery, code, 0, _key, value, 'no proof', 0, log}, ^state} =
      handle_call({:RequestQuery, "", key, 0, false}, nil, state)

    # NOTE that (by the ABCI standard from abci_server) the query result is a char list and
    #           (by our own standard) a json
    %{code: code, value: value |> to_string |> Poison.decode!, log: log}
  end

  def found?(response, expected_value) do
    assert %{code: 0, value: ^expected_value} = response
    response
  end

  def not_found?(response) do
    assert %{code: 1, log: 'not_found'} = response
    response
  end

  def same?(response, expected_state) do
    assert %{state: ^expected_state} = response
    response
  end

  def assert_same_elements(l1, l2), do: assert Enum.sort(l1) == Enum.sort(l2)

  def tm_address(number) when is_integer(number) and number < 10  and number > -1 do
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA#{number}"
  end

  def pub_key(number) do
    <<1>> <> Base.decode16!(tm_address(number))
  end
end
