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
    {:ok, signature} = HonteD.Crypto.sign("0 CREATE_TOKEN #{issuer.addr}", issuer.priv)
    {:reply, _, state} =
      handle_call({:RequestDeliverTx, "0 CREATE_TOKEN #{issuer.addr} #{signature}"}, nil, empty_state)
    state
  end
  
  deffixture state_alice_has_tokens(state_with_token, alice, issuer, asset) do
    {:ok, signature} = HonteD.Crypto.sign("1 ISSUE #{asset} 5 #{alice.addr} #{issuer.addr}", issuer.priv)
    {:reply, _, state} =
      handle_call({:RequestDeliverTx, "1 ISSUE #{asset} 5 #{alice.addr} #{issuer.addr} #{signature}"}, 
                  nil, 
                  state_with_token)
    state
  end

  @tag fixtures: [:empty_state]
  test "info about clean state", %{empty_state: state} do
    assert {:reply, {:ResponseInfo, 'arbitrary information', 'version info', 0, ''}, ^state} = handle_call({:RequestInfo}, nil, state)
  end

  @tag fixtures: [:issuer, :empty_state]
  test "checking create_token transactions", %{empty_state: state, issuer: issuer} do
    
    {:ok, signature} = HonteD.Crypto.sign("0 CREATE_TOKEN #{issuer.addr}", issuer.priv)
    
    # correct
    assert {:reply, {:ResponseCheckTx, 0, '', ''}, ^state} =
      handle_call({:RequestCheckTx, "0 CREATE_TOKEN #{issuer.addr} #{signature}"}, nil, state)

    # malformed
    assert {:reply, {:ResponseCheckTx, 1, '', 'malformed_transaction'}, ^state} =
      handle_call({:RequestCheckTx, "0 CREATE_TOKE #{issuer.addr} #{signature}"}, nil, state)
    assert {:reply, {:ResponseCheckTx, 1, '', 'malformed_transaction'}, ^state} =
      handle_call({:RequestCheckTx, "0 CREATE_TOKEN asset #{issuer.addr} #{signature}"}, nil, state)
    assert {:reply, {:ResponseCheckTx, 1, '', 'malformed_transaction'}, ^state} =
      handle_call({:RequestCheckTx, "0 CREATE_TOKEN #{issuer.addr}"}, nil, state)      
  end
  
  @tag fixtures: [:alice, :issuer, :empty_state]
  test "signature checking in create_token", 
       %{empty_state: state, alice: alice, issuer: issuer} do
    
    # FIXME: dry these kinds of tests (see signature checking in send and issue)
    {:ok, alice_signature} = HonteD.Crypto.sign("0 CREATE_TOKEN #{issuer.addr}", alice.priv)
    
    assert {:reply, {:ResponseCheckTx, 1, '', 'invalid_signature'}, ^state} =
      handle_call({:RequestCheckTx, "0 CREATE_TOKEN #{issuer.addr} #{alice_signature}"}, nil, state)
  end

  @tag fixtures: [:alice, :issuer, :state_with_token, :asset]
  test "checking issue transactions",  
       %{state_with_token: state, alice: alice, issuer: issuer, asset: asset} do
    {:ok, signature} = HonteD.Crypto.sign("1 ISSUE #{asset} 5 #{alice.addr} #{issuer.addr}", issuer.priv)
    
    # correct
    assert {:reply, {:ResponseCheckTx, 0, '', ''}, ^state} =
      handle_call({:RequestCheckTx, "1 ISSUE #{asset} 5 #{alice.addr} #{issuer.addr} #{signature}"}, nil, state)

    # malformed
    assert {:reply, {:ResponseCheckTx, 1, '', 'malformed_transaction'}, ^state} =
      handle_call({:RequestCheckTx, "1 ISSU #{asset} 5 #{alice.addr} #{issuer.addr} #{signature}"}, nil, state)
    assert {:reply, {:ResponseCheckTx, 1, '', 'malformed_numbers'}, ^state} =
      handle_call({:RequestCheckTx, "1 ISSUE #{asset} 4.0 #{alice.addr} #{issuer.addr} #{signature}"}, nil, state)
    assert {:reply, {:ResponseCheckTx, 1, '', 'malformed_numbers'}, ^state} =
      handle_call({:RequestCheckTx, "1 ISSUE #{asset} 4.1 #{alice.addr} #{issuer.addr} #{signature}"}, nil, state)
    assert {:reply, {:ResponseCheckTx, 1, '', 'malformed_transaction'}, ^state} =
      handle_call({:RequestCheckTx, "1 ISSUE #{asset} 5 #{alice.addr} #{issuer.addr}"}, nil, state)      
    assert {:reply, {:ResponseCheckTx, 1, '', 'malformed_transaction'}, ^state} =
      handle_call({:RequestCheckTx, "1 ISSUE #{asset} 5 4 #{alice.addr} #{issuer.addr} #{signature}"}, nil, state)      
  end
  
  @tag fixtures: [:alice, :issuer, :state_with_token, :asset]
  test "signature checking in issue", 
       %{state_with_token: state, alice: alice, issuer: issuer, asset: asset} do
    
    # FIXME: dry these kinds of tests (see signature checking in send)
    {:ok, issuer_signature} = HonteD.Crypto.sign("1 ISSUE #{asset} 5 #{alice.addr} #{issuer.addr}", issuer.priv)
    {:ok, alice_signature} = HonteD.Crypto.sign("1 ISSUE #{asset} 5 #{alice.addr} #{issuer.addr}", alice.priv)
    
    assert {:reply, {:ResponseCheckTx, 1, '', 'invalid_signature'}, ^state} =
      handle_call({:RequestCheckTx, "1 ISSUE #{asset} 4 #{alice.addr} #{issuer.addr} #{issuer_signature}"}, nil, state)
    assert {:reply, {:ResponseCheckTx, 1, '', 'invalid_signature'}, ^state} =
      handle_call({:RequestCheckTx, "1 ISSUE #{asset} 5 #{alice.addr} #{issuer.addr} #{alice_signature}"}, nil, state)
  end
  
  describe "create token and issue transaction logic" do
    @tag fixtures: [:issuer, :alice, :empty_state, :asset]
    test "can't issue not-created token",
         %{issuer: issuer, alice: alice, empty_state: state, asset: asset} do
      
      {:ok, signature} = HonteD.Crypto.sign("0 ISSUE #{asset} 5 #{alice.addr} #{issuer.addr}", issuer.priv)
           
      assert {:reply, {:ResponseCheckTx, 1, '', 'unknown_issuer'}, ^state} =
        handle_call({:RequestCheckTx, "0 ISSUE #{asset} 5 #{alice.addr} #{issuer.addr} #{signature}"}, nil, state)
    end
    
    @tag fixtures: [:alice, :state_with_token, :asset]
    test "can't issue other issuer's token",
         %{alice: alice, state_with_token: state, asset: asset } do
      
      {:ok, signature} = HonteD.Crypto.sign("0 ISSUE #{asset} 5 #{alice.addr} #{alice.addr}", alice.priv)
           
      assert {:reply, {:ResponseCheckTx, 1, '', 'incorrect_issuer'}, ^state} =
        handle_call({:RequestCheckTx, "0 ISSUE #{asset} 5 #{alice.addr} #{alice.addr} #{signature}"}, nil, state)
    end
    
    @tag fixtures: [:issuer, :alice, :empty_state]
    test "can create and issue multiple tokens",
         %{issuer: issuer, alice: alice, empty_state: state } do
      
      {:ok, signature} = HonteD.Crypto.sign("0 CREATE_TOKEN #{issuer.addr}", issuer.priv)
           
      assert {:reply, {:ResponseDeliverTx, 0, '', ''}, state} =
        handle_call({:RequestDeliverTx, "0 CREATE_TOKEN #{issuer.addr} #{signature}"}, nil, state)
        
      {:ok, signature} = HonteD.Crypto.sign("1 CREATE_TOKEN #{issuer.addr}", issuer.priv)

      assert {:reply, {:ResponseDeliverTx, 0, '', ''}, state} =
        handle_call({:RequestDeliverTx, "1 CREATE_TOKEN #{issuer.addr} #{signature}"}, nil, state)
      
      asset0 = HonteD.Token.create_address(issuer.addr, 0)
      asset1 = HonteD.Token.create_address(issuer.addr, 1)
      
      assert asset0 != asset1

      {:ok, signature} = HonteD.Crypto.sign("2 ISSUE #{asset0} 5 #{alice.addr} #{issuer.addr}", issuer.priv)
      assert {:reply, {:ResponseDeliverTx, 0, '', ''}, state} =
        handle_call({:RequestDeliverTx, "2 ISSUE #{asset0} 5 #{alice.addr} #{issuer.addr} #{signature}"}, nil, state)
        
      {:ok, signature} = HonteD.Crypto.sign("3 ISSUE #{asset1} 5 #{alice.addr} #{issuer.addr}", issuer.priv)
        
      assert {:reply, {:ResponseDeliverTx, 0, '', ''}, _} =
        handle_call({:RequestDeliverTx, "3 ISSUE #{asset1} 5 #{alice.addr} #{issuer.addr} #{signature}"}, nil, state)

    end
  end
  
  @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
  test "checking send transactions", 
       %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
    
    {:ok, signature} = HonteD.Crypto.sign("0 SEND #{asset} 5 #{alice.addr} #{bob.addr}", alice.priv)
      
    # correct
    assert {:reply, {:ResponseCheckTx, 0, '', ''}, ^state} =
      handle_call({:RequestCheckTx, "0 SEND #{asset} 5 #{alice.addr} #{bob.addr} #{signature}"}, nil, state)
      
    # malformed
    assert {:reply, {:ResponseCheckTx, 1, '', 'malformed_transaction'}, ^state} =
      handle_call({:RequestCheckTx, "0 SEN #{asset} 5 #{alice.addr} #{bob.addr} #{signature}"}, nil, state)
    assert {:reply, {:ResponseCheckTx, 1, '', 'malformed_numbers'}, ^state} =
      handle_call({:RequestCheckTx, "0 SEND #{asset} 4.0 #{alice.addr} #{bob.addr} #{signature}"}, nil, state)
    assert {:reply, {:ResponseCheckTx, 1, '', 'malformed_numbers'}, ^state} =
      handle_call({:RequestCheckTx, "0 SEND #{asset} 4.1 #{alice.addr} #{bob.addr} #{signature}"}, nil, state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
  test "querying nonces", 
       %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
    
    {:ok, signature} = HonteD.Crypto.sign("0 SEND #{asset} 5 #{alice.addr} #{bob.addr}", alice.priv)

    assert {:reply, {:ResponseQuery, 0, 0, _key, '0', 'no proof', _, ''}, ^state} =
      handle_call({:RequestQuery, "", '/nonces/#{alice.addr}', 0, false}, nil, state)

    {:reply, _, state} =
      handle_call({:RequestDeliverTx, "0 SEND #{asset} 5 #{alice.addr} #{bob.addr} #{signature}"}, nil, state)

    assert {:reply, {:ResponseQuery, 0, 0, _key, '0', 'no proof', _, ''}, ^state} =
      handle_call({:RequestQuery, "", '/nonces/#{bob.addr}', 0, false}, nil, state)

    assert {:reply, {:ResponseQuery, 0, 0, _key, '1', 'no proof', _, ''}, ^state} =
      handle_call({:RequestQuery, "", '/nonces/#{alice.addr}', 0, false}, nil, state)
  end

  @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
  test "checking nonces", 
       %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
    
    {:ok, signature0} = HonteD.Crypto.sign("0 SEND #{asset} 1 #{alice.addr} #{bob.addr}", alice.priv)
    {:ok, signature1} = HonteD.Crypto.sign("1 SEND #{asset} 1 #{alice.addr} #{bob.addr}", alice.priv)
    {:ok, signature2} = HonteD.Crypto.sign("2 SEND #{asset} 1 #{alice.addr} #{bob.addr}", alice.priv)

    assert {:reply, {:ResponseCheckTx, 1, '', 'invalid_nonce'}, ^state} =
      handle_call({:RequestCheckTx, "1 SEND #{asset} 1 #{alice.addr} #{bob.addr} #{signature1}"}, nil, state)
      
    {:reply, _, state} =
      handle_call({:RequestDeliverTx, "0 SEND #{asset} 1 #{alice.addr} #{bob.addr} #{signature0}"}, nil, state)

    assert {:reply, {:ResponseCheckTx, 1, '', 'invalid_nonce'}, ^state} =
      handle_call({:RequestCheckTx, "0 SEND #{asset} 1 #{alice.addr} #{bob.addr} #{signature0}"}, nil, state)
    assert {:reply, {:ResponseCheckTx, 1, '', 'invalid_nonce'}, ^state} =
      handle_call({:RequestCheckTx, "2 SEND #{asset} 1 #{alice.addr} #{bob.addr} #{signature2}"}, nil, state)
    assert {:reply, {:ResponseCheckTx, 0, '', ''}, ^state} =
      handle_call({:RequestCheckTx, "1 SEND #{asset} 1 #{alice.addr} #{bob.addr} #{signature1}"}, nil, state)
  end
  
  @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
  test "nonces common for all transaction types",
       %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
    {:ok, signature_send} = HonteD.Crypto.sign("0 SEND #{asset} 1 #{alice.addr} #{bob.addr}", alice.priv)
    {:reply, _, state} =
      handle_call({:RequestDeliverTx, "0 SEND #{asset} 1 #{alice.addr} #{bob.addr} #{signature_send}"}, nil, state)
    
    # check transactions other than send
    {:ok, signature_create} = HonteD.Crypto.sign("0 CREATE_TOKEN #{alice.addr}", alice.priv)
    {:ok, signature_issue} = HonteD.Crypto.sign("0 ISSUE 5 #{asset} #{alice.addr} #{alice.addr}", alice.priv)
    
    assert {:reply, {:ResponseCheckTx, 1, '', 'invalid_nonce'}, ^state} =
      handle_call({:RequestCheckTx, "0 CREATE_TOKEN #{alice.addr} #{signature_create}"}, nil, state)
    assert {:reply, {:ResponseCheckTx, 1, '', 'invalid_nonce'}, ^state} =
      handle_call({:RequestCheckTx, "0 ISSUE #{asset} 5 #{alice.addr} #{alice.addr} #{signature_issue}"}, nil, state)
    assert {:reply, {:ResponseCheckTx, 1, '', 'invalid_nonce'}, ^state} =
      handle_call({:RequestCheckTx, "0 SEND #{asset} 1 #{alice.addr} #{bob.addr} #{signature_send}"}, nil, state)
  end

  @tag fixtures: [:issuer, :empty_state]
  test "hash from commits changes on state update",
       %{empty_state: state, issuer: issuer} do
    
    assert {:reply, {:ResponseCommit, 0, cleanhash, _}, ^state} = 
      handle_call({:RequestCommit}, nil, state)
      
    {:ok, signature} = HonteD.Crypto.sign("0 CREATE_TOKEN #{issuer.addr}", issuer.priv)
    
    {:reply, _, state} =
      handle_call({:RequestDeliverTx, "0 CREATE_TOKEN #{issuer.addr} #{signature}"}, nil, state)
      
    assert {:reply, {:ResponseCommit, 0, newhash, _}, ^state} = 
      handle_call({:RequestCommit}, nil, state)
      
    assert newhash != cleanhash
  end
  
  describe "send transactions logic" do
    @tag fixtures: [:bob, :state_alice_has_tokens, :asset]
    test "bob has nothing (sanity)",
         %{state_alice_has_tokens: state, bob: bob, asset: asset} do
    
      assert {:reply, {:ResponseQuery, 1, 0, _key, '', 'no proof', _, 'not_found'}, ^state} =
        handle_call({:RequestQuery, "", '/accounts/#{asset}/#{bob.addr}', 0, false}, nil, state)
    end
      
    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "correct transfer",
         %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      {:ok, signature} = HonteD.Crypto.sign("0 SEND #{asset} 1 #{alice.addr} #{bob.addr}", alice.priv)
      
      assert {:reply, {:ResponseDeliverTx, 0, '', ''}, state} =
        handle_call({:RequestDeliverTx, "0 SEND #{asset} 1 #{alice.addr} #{bob.addr} #{signature}"}, nil, state)
      assert {:reply, {:ResponseQuery, 0, 0, _key, '1', 'no proof', _, ''}, ^state} =
        handle_call({:RequestQuery, "", '/accounts/#{asset}/#{bob.addr}', 0, false}, nil, state)
      assert {:reply, {:ResponseQuery, 0, 0, _key, '4', 'no proof', _, ''}, ^state} =
        handle_call({:RequestQuery, "", '/accounts/#{asset}/#{alice.addr}', 0, false}, nil, state)
    end
    
    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "insufficient funds",
         %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      {:ok, signature} = HonteD.Crypto.sign("0 SEND #{asset} 6 #{alice.addr} #{bob.addr}", alice.priv)
      
      assert {:reply, {:ResponseCheckTx, 1, '', 'insufficient_funds'}, ^state} =
        handle_call({:RequestCheckTx, "0 SEND #{asset} 6 #{alice.addr} #{bob.addr} #{signature}"}, nil, state)
    end
    
    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "negative amount",
         %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      {:ok, signature} = HonteD.Crypto.sign("0 SEND #{asset} -1 #{alice.addr} #{bob.addr}", alice.priv)
      
      assert {:reply, {:ResponseCheckTx, 1, '', 'positive_amount_required'}, ^state} =
        handle_call({:RequestCheckTx, "0 SEND #{asset} -1 #{alice.addr} #{bob.addr} #{signature}"}, nil, state)
    end
    
    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "zero amount",
         %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      {:ok, signature} = HonteD.Crypto.sign("0 SEND #{asset} 0 #{alice.addr} #{bob.addr}", alice.priv)
      
      assert {:reply, {:ResponseCheckTx, 1, '', 'positive_amount_required'}, ^state} =
        handle_call({:RequestCheckTx, "0 SEND #{asset} 0 #{alice.addr} #{bob.addr} #{signature}"}, nil, state)
    end      
    
    @tag fixtures: [:bob, :state_alice_has_tokens, :asset]
    test "unknown sender",
         %{state_alice_has_tokens: state, bob: bob, asset: asset} do
      assert {:reply, {:ResponseCheckTx, 1, '', 'insufficient_funds'}, ^state} =
        handle_call({:RequestCheckTx, "0 SEND #{asset} 5 carol #{bob.addr} carols_signature"}, nil, state)
    end
    
    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "second consecutive transfer",
         %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      
      {:ok, signature} = HonteD.Crypto.sign("0 SEND #{asset} 1 #{alice.addr} #{bob.addr}", alice.priv)
      assert {:reply, _, state} =
        handle_call({:RequestDeliverTx, "0 SEND #{asset} 1 #{alice.addr} #{bob.addr} #{signature}"}, nil, state)
        
      {:ok, signature1_4} = HonteD.Crypto.sign("1 SEND #{asset} 4 #{alice.addr} #{bob.addr}", alice.priv)

      assert {:reply, {:ResponseCheckTx, 0, '', ''}, ^state} =
        handle_call({:RequestCheckTx, "1 SEND #{asset} 4 #{alice.addr} #{bob.addr} #{signature1_4}"}, nil, state)
      assert {:reply, {:ResponseDeliverTx, 0, '', ''}, state} =
        handle_call({:RequestDeliverTx, "1 SEND #{asset} 4 #{alice.addr} #{bob.addr} #{signature1_4}"}, nil, state)
        
      assert {:reply, {:ResponseQuery, 0, 0, _key, '5', 'no proof', _, ''}, ^state} =
        handle_call({:RequestQuery, "", '/accounts/#{asset}/#{bob.addr}', 0, false}, nil, state)
      assert {:reply, {:ResponseQuery, 0, 0, _key, '0', 'no proof', _, ''}, ^state} =
        handle_call({:RequestQuery, "", '/accounts/#{asset}/#{alice.addr}', 0, false}, nil, state)
    end
    
    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "signature checking in send",
         %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      
      {:ok, alice_signature} = HonteD.Crypto.sign("0 SEND #{asset} 1 #{alice.addr} #{bob.addr}", alice.priv)
      {:ok, bob_signature} = HonteD.Crypto.sign("0 SEND #{asset} 1 #{alice.addr} #{bob.addr}", bob.priv)
      
      assert {:reply, {:ResponseCheckTx, 1, '', 'invalid_signature'}, ^state} =
        handle_call({:RequestCheckTx, "0 SEND #{asset} 4 #{alice.addr} #{bob.addr} #{alice_signature}"}, nil, state)
      assert {:reply, {:ResponseCheckTx, 1, '', 'invalid_signature'}, ^state} =
        handle_call({:RequestCheckTx, "0 SEND #{asset} 1 #{alice.addr} #{bob.addr} #{bob_signature}"}, nil, state)
    end
  end
  
  ## HELPER functions
  defp generate_entity() do
    {:ok, priv} = HonteD.Crypto.generate_private_key
    {:ok, pub} = HonteD.Crypto.generate_public_key(priv)
    {:ok, addr} = HonteD.Crypto.generate_address(pub)
    %{priv: priv, addr: addr}    
  end

end
