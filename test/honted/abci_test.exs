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
    # FIXME: should avoid using HonteD.Crypto in favor of HonteD.API (multiple places)
    # remove HonteD.Crypto usage as HonteD.API gets implemented
    %{
      alice_info: generate_entity(),
      bob_info: generate_entity(),
      issuer_info: generate_entity(),
    }
  end
  
  deffixture asset(entities) do
    %{issuer_info: issuer} = entities
    HonteD.Token.create_address(issuer.addr, 0)
  end
  
  deffixture state_with_token(empty_state, entities) do
    %{issuer_info: issuer} = entities
    {:ok, signature} = HonteD.Crypto.sign("0 CREATE_TOKEN #{issuer.addr}", issuer.priv)
    {:reply, _, state} =
      handle_call({:RequestDeliverTx, "0 CREATE_TOKEN #{issuer.addr} #{signature}"}, nil, empty_state)
    state
  end
  
  deffixture state_alice_has_5(state_with_token, entities, asset) do
    %{alice_info: alice, issuer_info: issuer} = entities
    {:ok, signature} = HonteD.Crypto.sign("1 ISSUE #{asset} 5 #{alice.addr} #{issuer.addr}", issuer.priv)
    {:reply, _, state} =
      handle_call({:RequestDeliverTx, "1 ISSUE #{asset} 5 #{alice.addr} #{issuer.addr} #{signature}"}, nil, state_with_token)
    state
  end

  @tag fixtures: [:empty_state]
  test "info about clean state", %{empty_state: state} do
    assert {:reply, {:ResponseInfo, 'arbitrary information', 'version info', 0, ''}, ^state} = handle_call({:RequestInfo}, nil, state)
  end

  @tag fixtures: [:entities, :empty_state]
  test "checking create_token transactions",  %{empty_state: state, entities: %{issuer_info: issuer}} do
    
    {:ok, signature} = HonteD.Crypto.sign("0 CREATE_TOKEN #{issuer.addr}", issuer.priv)
    
    # correct
    assert {:reply, {:ResponseCheckTx, 0, '', ''}, ^state} =
      handle_call({:RequestCheckTx, "0 CREATE_TOKEN #{issuer.addr} #{signature}"}, nil, state)

    # malformed
    assert {:reply, {:ResponseCheckTx, 1, '', 'malformed_transaction'}, ^state} =
      handle_call({:RequestCheckTx, "0 CREATE_TOKE #{issuer.addr} #{signature}"}, nil, state)
    assert {:reply, {:ResponseCheckTx, 1, '', 'malformed_transaction'}, ^state} =
      handle_call({:RequestCheckTx, "0 CREATE_TOKEN asset #{issuer.addr} #{signature}"}, nil, state)
  end

  @tag fixtures: [:entities, :state_with_token, :asset]
  test "checking issue transactions",  
       %{entities: %{alice_info: alice, issuer_info: issuer}, state_with_token: state, asset: asset} do
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
  end
  
  @tag fixtures: [:entities, :state_with_token, :asset]
  test "signature checking in issue", 
       %{state_with_token: state, entities: %{alice_info: alice, issuer_info: issuer}, asset: asset} do
    
    # FIXME: dry these kinds of tests (see signature checking in send)
    {:ok, issuer_signature} = HonteD.Crypto.sign("1 ISSUE #{asset} 5 #{alice.addr} #{issuer.addr}", issuer.priv)
    {:ok, alice_signature} = HonteD.Crypto.sign("1 ISSUE #{asset} 5 #{alice.addr} #{issuer.addr}", alice.priv)
    
    assert {:reply, {:ResponseCheckTx, 1, '', 'invalid_signature'}, ^state} =
      handle_call({:RequestCheckTx, "1 ISSUE #{asset} 4 #{alice.addr} #{issuer.addr} #{issuer_signature}"}, nil, state)
    assert {:reply, {:ResponseCheckTx, 1, '', 'invalid_signature'}, ^state} =
      handle_call({:RequestCheckTx, "1 ISSUE #{asset} 5 #{alice.addr} #{issuer.addr} #{alice_signature}"}, nil, state)
  end
  
  @tag fixtures: [:entities, :state_alice_has_5, :asset]
  test "checking send transactions", 
       %{state_alice_has_5: state, entities: %{alice_info: alice, bob_info: bob}, asset: asset} do
    
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

  @tag fixtures: [:entities, :state_alice_has_5, :asset]
  test "querying nonces", 
       %{state_alice_has_5: state, entities: %{alice_info: alice, bob_info: bob}, asset: asset} do
    
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

  @tag fixtures: [:entities, :state_alice_has_5, :asset]
  test "checking nonces", 
       %{state_alice_has_5: state, entities: %{alice_info: alice, bob_info: bob}, asset: asset} do
    
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

  @tag fixtures: [:entities, :empty_state]
  test "hash from commits changes on state update",
       %{empty_state: state, entities: %{issuer_info: issuer}} do
    
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
    @tag fixtures: [:entities, :state_alice_has_5, :asset]
    test "bob has nothing (sanity)",
         %{state_alice_has_5: state, entities: %{bob_info: bob}, asset: asset} do
    
      assert {:reply, {:ResponseQuery, 1, 0, _key, '', 'no proof', _, 'not_found'}, ^state} =
        handle_call({:RequestQuery, "", '/accounts/#{asset}/#{bob.addr}', 0, false}, nil, state)
    end
      
    @tag fixtures: [:entities, :state_alice_has_5, :asset]
    test "correct transfer",
         %{state_alice_has_5: state, entities: %{alice_info: alice, bob_info: bob}, asset: asset} do
      {:ok, signature} = HonteD.Crypto.sign("0 SEND #{asset} 1 #{alice.addr} #{bob.addr}", alice.priv)
      
      assert {:reply, {:ResponseDeliverTx, 0, '', ''}, state} =
        handle_call({:RequestDeliverTx, "0 SEND #{asset} 1 #{alice.addr} #{bob.addr} #{signature}"}, nil, state)
      assert {:reply, {:ResponseQuery, 0, 0, _key, '1', 'no proof', _, ''}, ^state} =
        handle_call({:RequestQuery, "", '/accounts/#{asset}/#{bob.addr}', 0, false}, nil, state)
      assert {:reply, {:ResponseQuery, 0, 0, _key, '4', 'no proof', _, ''}, ^state} =
        handle_call({:RequestQuery, "", '/accounts/#{asset}/#{alice.addr}', 0, false}, nil, state)
    end
    
    @tag fixtures: [:entities, :state_alice_has_5, :asset]
    test "insufficient funds",
         %{state_alice_has_5: state, entities: %{alice_info: alice, bob_info: bob}, asset: asset} do
      {:ok, signature} = HonteD.Crypto.sign("0 SEND #{asset} 6 #{alice.addr} #{bob.addr}", alice.priv)
      
      assert {:reply, {:ResponseCheckTx, 1, '', 'insufficient_funds'}, ^state} =
        handle_call({:RequestCheckTx, "0 SEND #{asset} 6 #{alice.addr} #{bob.addr} #{signature}"}, nil, state)
    end
    
    @tag fixtures: [:entities, :state_alice_has_5, :asset]
    test "negative amount",
         %{state_alice_has_5: state, entities: %{alice_info: alice, bob_info: bob}, asset: asset} do
      {:ok, signature} = HonteD.Crypto.sign("0 SEND #{asset} -1 #{alice.addr} #{bob.addr}", alice.priv)
      
      assert {:reply, {:ResponseCheckTx, 1, '', 'positive_amount_required'}, ^state} =
        handle_call({:RequestCheckTx, "0 SEND #{asset} -1 #{alice.addr} #{bob.addr} #{signature}"}, nil, state)
    end
    
    @tag fixtures: [:entities, :state_alice_has_5, :asset]
    test "zero amount",
         %{state_alice_has_5: state, entities: %{alice_info: alice, bob_info: bob}, asset: asset} do
      {:ok, signature} = HonteD.Crypto.sign("0 SEND #{asset} 0 #{alice.addr} #{bob.addr}", alice.priv)
      
      assert {:reply, {:ResponseCheckTx, 1, '', 'positive_amount_required'}, ^state} =
        handle_call({:RequestCheckTx, "0 SEND #{asset} 0 #{alice.addr} #{bob.addr} #{signature}"}, nil, state)
    end      
    
    @tag fixtures: [:entities, :state_alice_has_5, :asset]
    test "unknown sender",
         %{state_alice_has_5: state, entities: %{bob_info: bob}, asset: asset} do
      assert {:reply, {:ResponseCheckTx, 1, '', 'insufficient_funds'}, ^state} =
        handle_call({:RequestCheckTx, "0 SEND #{asset} 5 carol #{bob.addr} carols_signature"}, nil, state)
    end
    
    @tag fixtures: [:entities, :state_alice_has_5, :asset]
    test "second consecutive transfer",
         %{state_alice_has_5: state, entities: %{alice_info: alice, bob_info: bob}, asset: asset} do
      
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
    
    @tag fixtures: [:entities, :state_alice_has_5, :asset]
    test "signature checking in send",
         %{state_alice_has_5: state, entities: %{alice_info: alice, bob_info: bob}, asset: asset} do
      
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
