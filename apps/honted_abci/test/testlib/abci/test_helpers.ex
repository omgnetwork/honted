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
  def do_tx(request_atom, response_atom, signed_tx, abci_app) do
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
end
