defmodule HonteD.ABCITest do
  @moduledoc """
  **NOTE** this test will pretend to be Tendermint core
  """
  use ExUnitFixtures
  use ExUnit.Case, async: true
  doctest HonteD

  import HonteD.ABCI

  deffixture empty_state do
    {:ok, state} = HonteD.ABCI.init(:ok)
    state
  end
    
  deffixture entities do
    %{
      alice: generate_entity(),
      bob: generate_entity(),
      issuer: generate_entity(),
    }
  end
  
  deffixture alice(entities), do: entities.alice
  deffixture bob(entities), do: entities.bob
  deffixture issuer(entities), do: entities.issuer
  
  deffixture asset(issuer) do
    # FIXME: as soon as that functionality lands, we should use HonteD.API to discover newly created token addresses
    # (multiple occurrences!)
    HonteD.Token.create_address(issuer.addr, 0)
  end
  
  deffixture state_with_token(empty_state, issuer) do
    %{code: 0, state: state} = sign("0 CREATE_TOKEN #{issuer.addr}", issuer.priv) |> deliver_tx(empty_state)
    state
  end
  
  deffixture state_alice_has_tokens(state_with_token, alice, issuer, asset) do
    %{code: 0, state: state} = 
      sign("1 ISSUE #{asset} 5 #{alice.addr} #{issuer.addr}", issuer.priv) |> deliver_tx(state_with_token)
    state
  end

  describe "info requests from tendermint" do
    @tag fixtures: [:empty_state]
    test "info about clean state", %{empty_state: state} do
      assert {:reply, {:ResponseInfo, 'arbitrary information', 'version info', 0, ''}, ^state} = handle_call({:RequestInfo}, nil, state)
    end
  end

  describe "commits" do
    @tag fixtures: [:issuer, :empty_state]
    test "hash from commits changes on state update", %{empty_state: state, issuer: issuer} do
      assert {:reply, {:ResponseCommit, 0, cleanhash, _}, ^state} = handle_call({:RequestCommit}, nil, state)
        
      %{state: state} = sign("0 CREATE_TOKEN #{issuer.addr}", issuer.priv) |> deliver_tx(state) |> success?
        
      assert {:reply, {:ResponseCommit, 0, newhash, _}, ^state} =  handle_call({:RequestCommit}, nil, state)
      assert newhash != cleanhash
    end
  end

  describe "well formedness of create_token transactions" do
    @tag fixtures: [:issuer, :empty_state]
    test "checking create_token transactions", %{empty_state: state, issuer: issuer} do
      # correct
      sign("0 CREATE_TOKEN #{issuer.addr}", issuer.priv) |> check_tx(state) |> success? |> same?(state)
      
      # malformed
      sign("0 CREATE_TOKE #{issuer.addr}", issuer.priv) |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
      sign("0 CREATE_TOKE asset #{issuer.addr}", issuer.priv) |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
        
      # no signature
      "0 CREATE_TOKEN #{issuer.addr}" |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
    end
    
    @tag fixtures: [:alice, :issuer, :empty_state]
    test "signature checking in create_token", %{empty_state: state, alice: alice, issuer: issuer} do
      sign("0 CREATE_TOKEN #{issuer.addr}", alice.priv) |> check_tx(state) |> fail?(1, 'invalid_signature') |> same?(state)
    end
  end

  describe "well formedness of issue transactions" do
    @tag fixtures: [:alice, :issuer, :state_with_token, :asset]
    test "checking issue transactions", %{state_with_token: state, alice: alice, issuer: issuer, asset: asset} do
      sign("1 ISSUE #{asset} 5 #{alice.addr} #{issuer.addr}", issuer.priv) |> check_tx(state) |> success? |> same?(state)

      # malformed
      sign("1 ISSU #{asset} 5 #{alice.addr} #{issuer.addr}", issuer.priv) |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
      sign("1 ISSUE #{asset} 4.0 #{alice.addr} #{issuer.addr}", issuer.priv) |> check_tx(state) |> fail?(1, 'malformed_numbers') |> same?(state)
      sign("1 ISSUE #{asset} 4.1 #{alice.addr} #{issuer.addr}", issuer.priv) |> check_tx(state) |> fail?(1, 'malformed_numbers') |> same?(state)
      "1 ISSUE #{asset} 5 #{alice.addr} #{issuer.addr}" |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
      sign("1 ISSUE #{asset} 5 4 #{alice.addr} #{issuer.addr}", issuer.priv) |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
    end
  
    @tag fixtures: [:alice, :issuer, :state_with_token, :asset]
    test "signature checking in issue", %{state_with_token: state, alice: alice, issuer: issuer, asset: asset} do
      {:ok, issuer_signature} = HonteD.Crypto.sign("1 ISSUE #{asset} 5 #{alice.addr} #{issuer.addr}", issuer.priv)
      assert {:reply, {:ResponseCheckTx, 1, '', 'invalid_signature'}, ^state} =
        handle_call({:RequestCheckTx, "1 ISSUE #{asset} 4 #{alice.addr} #{issuer.addr} #{issuer_signature}"}, nil, state)
        
      sign("1 ISSUE #{asset} 5 #{alice.addr} #{issuer.addr}", alice.priv) |> check_tx(state) |> fail?(1, 'invalid_signature') |> same?(state)
    end
  end
  
  describe "create token and issue transaction logic" do
    @tag fixtures: [:issuer, :alice, :empty_state, :asset]
    test "can't issue not-created token", %{issuer: issuer, alice: alice, empty_state: state, asset: asset} do
      sign("0 ISSUE #{asset} 5 #{alice.addr} #{issuer.addr}", issuer.priv) |> check_tx(state) |> fail?(1, 'unknown_issuer') |> same?(state)
    end
    
    @tag fixtures: [:alice, :state_with_token, :asset]
    test "can't issue other issuer's token", %{alice: alice, state_with_token: state, asset: asset } do
      sign("0 ISSUE #{asset} 5 #{alice.addr} #{alice.addr}", alice.priv) |> check_tx(state) |> fail?(1, 'incorrect_issuer') |> same?(state)
    end
    
    @tag fixtures: [:issuer, :alice, :empty_state]
    test "can create and issue multiple tokens", %{issuer: issuer, alice: alice, empty_state: state } do
      %{state: state} = sign("0 CREATE_TOKEN #{issuer.addr}", issuer.priv) |> deliver_tx(state) |> success?
      %{state: state} = sign("1 CREATE_TOKEN #{issuer.addr}", issuer.priv) |> deliver_tx(state) |> success?
      %{state: state} = sign("0 CREATE_TOKEN #{alice.addr}", alice.priv) |> deliver_tx(state) |> success?
      %{state: state} = sign("1 CREATE_TOKEN #{alice.addr}", alice.priv) |> deliver_tx(state) |> success?
      
      asset0 = HonteD.Token.create_address(issuer.addr, 0)
      asset1 = HonteD.Token.create_address(issuer.addr, 1)
      asset2 = HonteD.Token.create_address(alice.addr, 0)
      
      # check that they're different
      assert asset0 != asset1
      assert asset0 != asset2

      # check that they all actually exist and function as intended
      %{state: state} = sign("2 ISSUE #{asset0} 5 #{alice.addr} #{issuer.addr}", issuer.priv) |> deliver_tx(state) |> success?
      %{state: state} = sign("2 ISSUE #{asset2} 5 #{alice.addr} #{alice.addr}", alice.priv) |> deliver_tx(state) |> success?
      %{state: _} = sign("3 ISSUE #{asset1} 5 #{alice.addr} #{issuer.addr}", issuer.priv) |> deliver_tx(state) |> success?
    end
    
    @tag fixtures: [:issuer, :alice, :state_with_token, :asset]
    test "can't overflow in issue", %{issuer: issuer, alice: alice, state_with_token: state, asset: asset} do
      sign("1 ISSUE #{asset} #{round(:math.pow(2, 256))} #{alice.addr} #{issuer.addr}", issuer.priv) 
      |> check_tx(state) |> fail?(1, 'amount_way_too_large') |> same?(state)
      sign("1 ISSUE #{asset} #{round(:math.pow(2, 256)) - 1} #{alice.addr} #{issuer.addr}", issuer.priv) 
      |> check_tx(state) |> success? |> same?(state)
    end
  end
  
  describe "well formedness of send transactions" do
    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "checking send transactions", %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      sign("0 SEND #{asset} 5 #{alice.addr} #{bob.addr}", alice.priv) |> check_tx(state) |> success?
        
      # malformed
      sign("0 SEN #{asset} 5 #{alice.addr} #{bob.addr}", alice.priv) |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
      sign("0 SEND #{asset} 4.0 #{alice.addr} #{bob.addr}", alice.priv) |> check_tx(state) |> fail?(1, 'malformed_numbers') |> same?(state)
      sign("0 SEND #{asset} 4.1 #{alice.addr} #{bob.addr}", alice.priv) |> check_tx(state) |> fail?(1, 'malformed_numbers') |> same?(state)
      sign("0 SEND #{asset} 5 4 #{alice.addr} #{bob.addr}", alice.priv) |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
      "0 SEND #{asset} 5 4 #{alice.addr} #{bob.addr}" |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
    end
  end
  
  describe "generic nonce tests" do
    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "querying nonces", %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      query(state, '/nonces/#{alice.addr}') |> found?('0')

      %{state: state} = sign("0 SEND #{asset} 5 #{alice.addr} #{bob.addr}", alice.priv) |> deliver_tx(state) |> success?
      
      query(state, '/nonces/#{bob.addr}') |> found?('0')
      query(state, '/nonces/#{alice.addr}') |> found?('1')
    end

    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "checking nonces", %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      sign("1 SEND #{asset} 1 #{alice.addr} #{bob.addr}", alice.priv) |> check_tx(state) |> fail?(1, 'invalid_nonce') |> same?(state)
      %{state: state} = sign("0 SEND #{asset} 1 #{alice.addr} #{bob.addr}", alice.priv) |> deliver_tx(state) |> success?
      sign("0 SEND #{asset} 1 #{alice.addr} #{bob.addr}", alice.priv) |> check_tx(state) |> fail?(1, 'invalid_nonce') |> same?(state)
      sign("2 SEND #{asset} 1 #{alice.addr} #{bob.addr}", alice.priv) |> check_tx(state) |> fail?(1, 'invalid_nonce') |> same?(state)
      sign("1 SEND #{asset} 1 #{alice.addr} #{bob.addr}", alice.priv) |> check_tx(state) |> success? |> same?(state)
    end
    
    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "nonces common for all transaction types", %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      %{state: state} = sign("0 SEND #{asset} 1 #{alice.addr} #{bob.addr}", alice.priv) |> deliver_tx(state) |> success?
      
      # check transactions other than send
      sign("0 CREATE_TOKEN #{alice.addr}", alice.priv) |> check_tx(state) |> fail?(1, 'invalid_nonce') |> same?(state)
      sign("0 ISSUE #{asset} 5 #{alice.addr} #{alice.addr}", alice.priv) |> check_tx(state) |> fail?(1, 'invalid_nonce') |> same?(state)
      sign("0 SEND #{asset} 1 #{alice.addr} #{bob.addr}", alice.priv) |> check_tx(state) |> fail?(1, 'invalid_nonce') |> same?(state)
    end
  end
  
  describe "send transactions logic" do
    @tag fixtures: [:bob, :state_alice_has_tokens, :asset]
    test "bob has nothing (sanity)", %{state_alice_has_tokens: state, bob: bob, asset: asset} do
      query(state, '/accounts/#{asset}/#{bob.addr}') |> not_found?
    end
      
    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "correct transfer", %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      %{state: state} = sign("0 SEND #{asset} 1 #{alice.addr} #{bob.addr}", alice.priv) |> deliver_tx(state) |> success?
      query(state, '/accounts/#{asset}/#{bob.addr}') |> found?('1')
      query(state, '/accounts/#{asset}/#{alice.addr}') |> found?('4')
    end
    
    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "insufficient funds", %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      sign("0 SEND #{asset} 6 #{alice.addr} #{bob.addr}", alice.priv) |> check_tx(state) |> fail?(1, 'insufficient_funds') |> same?(state)
    end
    
    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "negative amount", %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      sign("0 SEND #{asset} -1 #{alice.addr} #{bob.addr}", alice.priv) |> check_tx(state) |> fail?(1, 'positive_amount_required') |> same?(state)
    end
    
    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "zero amount", %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      sign("0 SEND #{asset} 0 #{alice.addr} #{bob.addr}", alice.priv) |> check_tx(state) |> fail?(1, 'positive_amount_required') |> same?(state)
    end      
    
    @tag fixtures: [:bob, :state_alice_has_tokens, :asset]
    test "unknown sender", %{state_alice_has_tokens: state, bob: bob, asset: asset} do
      "0 SEND #{asset} 1 carol #{bob.addr} carols_signaturecarols_signaturecarols_signaturecarols_signature"
      |> check_tx(state) |> fail?(1, 'insufficient_funds') |> same?(state)
    end
    
    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "second consecutive transfer", %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      %{state: state} = sign("0 SEND #{asset} 1 #{alice.addr} #{bob.addr}", alice.priv) |> deliver_tx(state) |> success?
      %{state: state} = sign("1 SEND #{asset} 4 #{alice.addr} #{bob.addr}", alice.priv) |> deliver_tx(state) |> success?
        
      query(state, '/accounts/#{asset}/#{bob.addr}') |> found?('5')
      query(state, '/accounts/#{asset}/#{alice.addr}') |> found?('0')
    end
    
    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "signature checking in send", %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      {:ok, alice_signature} = HonteD.Crypto.sign("0 SEND #{asset} 1 #{alice.addr} #{bob.addr}", alice.priv)      
      assert {:reply, {:ResponseCheckTx, 1, '', 'invalid_signature'}, ^state} =
        handle_call({:RequestCheckTx, "0 SEND #{asset} 4 #{alice.addr} #{bob.addr} #{alice_signature}"}, nil, state)
        
      sign("0 SEND #{asset} 1 #{alice.addr} #{bob.addr}", bob.priv) |> check_tx(state) |> fail?(1, 'invalid_signature') |> same?(state)
    end
  end
  
  ## HELPER functions
  defp generate_entity() do
    {:ok, priv} = HonteD.Crypto.generate_private_key
    {:ok, pub} = HonteD.Crypto.generate_public_key(priv)
    {:ok, addr} = HonteD.Crypto.generate_address(pub)
    %{priv: priv, addr: addr}    
  end
  
  defp sign(raw_tx, priv_key) do
    {:ok, signature} = HonteD.Crypto.sign(raw_tx, priv_key)
    "#{raw_tx} #{signature}"
  end
  
  defp deliver_tx(signed_tx, state), do: do_tx(:RequestDeliverTx, :ResponseDeliverTx, signed_tx, state)
  defp check_tx(signed_tx, state), do: do_tx(:RequestCheckTx, :ResponseCheckTx, signed_tx, state)
  defp do_tx(request_atom, response_atom, signed_tx, state) do
    assert {:reply, {^response_atom, code, data, log}, state} = handle_call({request_atom, signed_tx}, nil, state)
    %{code: code, data: data, log: log, state: state}
  end
  
  defp success?(response) do
    assert %{code: 0, data: '', log: ''} = response
    response
  end
  
  defp fail?(response, expected_code, expected_log) do
    assert %{code: ^expected_code, data: '', log: ^expected_log} = response
    response
  end
  
  defp query(state, key) do
    assert {:reply, {:ResponseQuery, code, 0, _key, value, 'no proof', 0, log}, ^state} =
      handle_call({:RequestQuery, "", key, 0, false}, nil, state)
    %{code: code, value: value, log: log}
  end
  
  defp found?(response, expected_value) do
    assert %{code: 0, value: ^expected_value} = response
    response
  end
  
  defp not_found?(response) do
    assert %{code: 1, log: 'not_found'} = response
    response
  end

  defp same?(response, expected_state) do
    assert %{state: ^expected_state} = response
  end

end
