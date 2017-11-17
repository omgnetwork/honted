defmodule HonteD.ABCI.TestHelpers do

  import ExUnit.Assertions
  import HonteD.ABCI

  ## HELPER functions
  def generate_entity() do
    {:ok, priv} = HonteD.Crypto.generate_private_key
    {:ok, pub} = HonteD.Crypto.generate_public_key(priv)
    {:ok, addr} = HonteD.Crypto.generate_address(pub)
    %{priv: priv, addr: addr}
  end

  def sign({:ok, raw_tx}, priv_key), do: sign(raw_tx, priv_key)
  def sign(raw_tx, priv_key) do
    {:ok, signature} = HonteD.Crypto.sign(raw_tx, priv_key)
    "#{raw_tx} #{signature}"
  end

  def deliver_tx(signed_tx, state), do: do_tx(:RequestDeliverTx, :ResponseDeliverTx, signed_tx, state)
  def check_tx(signed_tx, state), do: do_tx(:RequestCheckTx, :ResponseCheckTx, signed_tx, state)
  def do_tx(request_atom, response_atom, {:ok, signed_tx}, state) do
    do_tx(request_atom, response_atom, signed_tx, state)
  end
  def do_tx(request_atom, response_atom, signed_tx, state) do
    assert {:reply, {^response_atom, code, data, log}, state} = handle_call({request_atom, signed_tx}, nil, state)
    %{code: code, data: data, log: log, state: state}
  end

  def success?(response) do
    assert %{code: 0, data: '', log: ''} = response
    response
  end

  def fail?(response, expected_code, expected_log) do
    assert %{code: ^expected_code, data: '', log: ^expected_log} = response
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
  end
end
