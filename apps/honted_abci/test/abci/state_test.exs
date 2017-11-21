defmodule HonteD.ABCI.StateTest do
  @moduledoc """
  **NOTE** this test will pretend to be Tendermint core
  """
  use ExUnitFixtures
  use ExUnit.Case, async: true

  import HonteD.ABCI.TestHelpers

  import HonteD.ABCI
  import HonteD.Transaction

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

      %{state: state} = create_create_token(nonce: 0, issuer: issuer.addr) |> sign(issuer.priv) |> deliver_tx(state) |> success?

      assert {:reply, {:ResponseCommit, 0, newhash, _}, ^state} =  handle_call({:RequestCommit}, nil, state)
      assert newhash != cleanhash
    end
  end

  describe "well formedness of create_token transactions" do
    @tag fixtures: [:issuer, :empty_state]
    test "checking create_token transactions", %{empty_state: state, issuer: issuer} do
      # correct
      create_create_token(nonce: 0, issuer: issuer.addr) |> sign(issuer.priv) |> check_tx(state) |> success? |> same?(state)

      # malformed
      sign("0 CREATE_TOKE #{issuer.addr}", issuer.priv)
      |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
      sign("0 CREATE_TOKE asset #{issuer.addr}", issuer.priv)
      |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)

      # no signature
      create_create_token(nonce: 0, issuer: issuer.addr)
      |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
    end

    @tag fixtures: [:alice, :issuer, :empty_state]
    test "signature checking in create_token", %{empty_state: state, alice: alice, issuer: issuer} do
      create_create_token(nonce: 0, issuer: issuer.addr)
      |> sign(alice.priv) |> check_tx(state) |> fail?(1, 'invalid_signature') |> same?(state)
    end
  end

  describe "well formedness of issue transactions" do
    @tag fixtures: [:alice, :issuer, :state_with_token, :asset]
    test "checking issue transactions", %{state_with_token: state, alice: alice, issuer: issuer, asset: asset} do
      create_issue(nonce: 1, asset: asset, amount: 5, dest: alice.addr, issuer: issuer.addr) 
      |> sign(issuer.priv) |> check_tx(state) |> success? |> same?(state)

      # malformed
      sign("1 ISSU #{asset} 5 #{alice.addr} #{issuer.addr}", issuer.priv)
      |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
      sign("1 ISSUE #{asset} 4.0 #{alice.addr} #{issuer.addr}", issuer.priv)
      |> check_tx(state) |> fail?(1, 'malformed_numbers') |> same?(state)
      sign("1 ISSUE #{asset} 4.1 #{alice.addr} #{issuer.addr}", issuer.priv)
      |> check_tx(state) |> fail?(1, 'malformed_numbers') |> same?(state)
      sign("1 ISSUE #{asset} 5 4 #{alice.addr} #{issuer.addr}", issuer.priv)
      |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
      
      # no signature
      create_issue(nonce: 1, asset: asset, amount: 5, dest: alice.addr, issuer: issuer.addr)
      |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
    end

    @tag fixtures: [:alice, :issuer, :state_with_token, :asset]
    test "signature checking in issue", %{state_with_token: state, alice: alice, issuer: issuer, asset: asset} do
      {:ok, tx1} = create_issue(nonce: 1, asset: asset, amount: 5, dest: alice.addr, issuer: issuer.addr)
      {:ok, tx2} = create_issue(nonce: 1, asset: asset, amount: 4, dest: alice.addr, issuer: issuer.addr)
      {:ok, issuer_signature} = HonteD.Crypto.sign(tx1, issuer.priv)
      
      assert {:reply, {:ResponseCheckTx, 1, '', 'invalid_signature'}, ^state} =
        handle_call({:RequestCheckTx, "#{tx2} #{issuer_signature}"}, nil, state)

      tx1 |> sign(alice.priv) |> check_tx(state) |> fail?(1, 'invalid_signature') |> same?(state)
    end
  end

  describe "create token and issue transaction logic" do
    @tag fixtures: [:issuer, :alice, :empty_state, :asset]
    test "can't issue not-created token", %{issuer: issuer, alice: alice, empty_state: state, asset: asset} do
      create_issue(nonce: 0, asset: asset, amount: 5, dest: alice.addr, issuer: issuer.addr)
      |> sign(issuer.priv) |> check_tx(state) |> fail?(1, 'unknown_issuer') |> same?(state)
    end

    @tag fixtures: [:issuer, :alice, :state_with_token, :asset]
    test "can't issue negative amount", %{state_with_token: state, alice: alice, issuer: issuer, asset: asset} do
      sign("0 ISSUE #{asset} -1 #{alice.addr} #{issuer.addr}", issuer.priv)
      |> check_tx(state) |> fail?(1, 'positive_amount_required') |> same?(state)
    end

    @tag fixtures: [:issuer, :alice, :state_with_token, :asset]
    test "can't issue zero amount", %{state_with_token: state, alice: alice, issuer: issuer, asset: asset} do
      sign("0 ISSUE #{asset} 0 #{alice.addr} #{issuer.addr}", issuer.priv)
      |> check_tx(state) |> fail?(1, 'positive_amount_required') |> same?(state)
    end

    @tag fixtures: [:empty_state, :asset]
    test "can't find not-created token infos", %{empty_state: state, asset: asset} do
      query(state, '/tokens/#{asset}/issuer') |> not_found?
      query(state, '/tokens/#{asset}/total_supply') |> not_found?
    end

    @tag fixtures: [:state_with_token, :asset]
    test "zero total supply on creation", %{state_with_token: state, asset: asset} do
      query(state, '/tokens/#{asset}/total_supply') |> found?(0)
    end

    @tag fixtures: [:alice, :state_with_token, :asset]
    test "can't issue other issuer's token", %{alice: alice, state_with_token: state, asset: asset } do
      create_issue(nonce: 0, asset: asset, amount: 5, dest: alice.addr, issuer: alice.addr)
      |> sign(alice.priv) |> check_tx(state) |> fail?(1, 'incorrect_issuer') |> same?(state)
    end

    @tag fixtures: [:issuer, :alice, :empty_state]
    test "can create and issue multiple tokens", %{issuer: issuer, alice: alice, empty_state: state } do
      %{state: state} = 
        create_create_token(nonce: 0, issuer: issuer.addr) |> sign(issuer.priv) |> deliver_tx(state) |> success?
      %{state: state} = 
        create_create_token(nonce: 1, issuer: issuer.addr) |> sign(issuer.priv) |> deliver_tx(state) |> success?
      %{state: state} = 
        create_create_token(nonce: 0, issuer: alice.addr) |> sign(alice.priv) |> deliver_tx(state) |> success?
      %{state: state} = 
        create_create_token(nonce: 1, issuer: alice.addr) |> sign(alice.priv) |> deliver_tx(state) |> success?

      asset0 = HonteD.Token.create_address(issuer.addr, 0)
      asset1 = HonteD.Token.create_address(issuer.addr, 1)
      asset2 = HonteD.Token.create_address(alice.addr, 0)

      # check that they're different
      assert asset0 != asset1
      assert asset0 != asset2

      # check that they all actually exist and function as intended
      %{state: state} = 
        create_issue(nonce: 2, asset: asset0, amount: 5, dest: alice.addr, issuer: issuer.addr)
        |> sign(issuer.priv) |> deliver_tx(state) |> success?
      %{state: state} = 
        create_issue(nonce: 2, asset: asset2, amount: 5, dest: alice.addr, issuer: alice.addr)
        |> sign(alice.priv) |> deliver_tx(state) |> success?
      %{state: _} =  
        create_issue(nonce: 3, asset: asset1, amount: 5, dest: alice.addr, issuer: issuer.addr)
        |> sign(issuer.priv) |> deliver_tx(state) |> success?
    end

    @tag fixtures: [:issuer, :alice, :state_with_token, :asset]
    test "can't overflow in issue", %{issuer: issuer, alice: alice, state_with_token: state, asset: asset} do
      create_issue(nonce: 1, asset: asset, amount: round(:math.pow(2, 256)), dest: alice.addr, issuer: issuer.addr)
      |> sign(issuer.priv) |> check_tx(state) |> fail?(1, 'amount_way_too_large') |> same?(state)
      
      # issue just under the limit to see error in next step
      %{state: state} =
        create_issue(nonce: 1, asset: asset, amount: round(:math.pow(2, 256)) - 1, dest: alice.addr, issuer: issuer.addr)
        |> sign(issuer.priv) |> deliver_tx(state) |> success?
        
      create_issue(nonce: 2, asset: asset, amount: 1, dest: alice.addr, issuer: issuer.addr)
      |> sign(issuer.priv) |> check_tx(state) |> fail?(1, 'amount_way_too_large') |> same?(state)
    end

    @tag fixtures: [:alice, :empty_state]
    test "can get empty list of issued tokens", %{alice: alice, empty_state: state} do
      query(state, '/issuers/#{alice.addr}') |> not_found?
    end

    @tag fixtures: [:issuer, :alice, :state_with_token, :asset]
    test "can list issued tokens", %{issuer: issuer, alice: alice, state_with_token: state, asset: asset} do
      query(state, '/issuers/#{issuer.addr}') |> found?([asset])
      %{state: state} =
        create_create_token(nonce: 1, issuer: issuer.addr) |> sign(issuer.priv) |> deliver_tx(state) |> success?
      %{state: state} =
        create_create_token(nonce: 0, issuer: alice.addr) |> sign(alice.priv) |> deliver_tx(state) |> success?
      asset1 = HonteD.Token.create_address(issuer.addr, 1)
      asset2 = HonteD.Token.create_address(alice.addr, 0)

      query(state, '/issuers/#{issuer.addr}') |> found?([asset1, asset])
      query(state, '/issuers/#{alice.addr}') |> found?([asset2])
    end

    @tag fixtures: [:issuer, :alice, :state_with_token, :asset]
    test "total supply and balance on issue", %{issuer: issuer, alice: alice, state_with_token: state, asset: asset} do
      %{state: state} =
        create_issue(nonce: 1, asset: asset, amount: 5, dest: alice.addr, issuer: issuer.addr)
        |> sign(issuer.priv) |> deliver_tx(state) |> success?
        
      query(state, '/tokens/#{asset}/total_supply') |> found?(5)
      query(state, '/accounts/#{asset}/#{alice.addr}') |> found?(5)
      
      %{state: state} = 
        create_issue(nonce: 2, asset: asset, amount: 7, dest: issuer.addr, issuer: issuer.addr)
        |> sign(issuer.priv) |> deliver_tx(state) |> success?
        
      query(state, '/tokens/#{asset}/total_supply') |> found?(12)
      query(state, '/accounts/#{asset}/#{alice.addr}') |> found?(5)
      query(state, '/accounts/#{asset}/#{issuer.addr}') |> found?(7)
    end
  end

  describe "well formedness of send transactions" do
    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "checking send transactions", %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      create_send(nonce: 0, asset: asset, amount: 5, from: alice.addr, to: bob.addr)
      |> sign(alice.priv) |> check_tx(state) |> success?

      # malformed
      sign("0 SEN #{asset} 5 #{alice.addr} #{bob.addr}", alice.priv)
      |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
      sign("0 SEND #{asset} 4.0 #{alice.addr} #{bob.addr}", alice.priv)
      |> check_tx(state) |> fail?(1, 'malformed_numbers') |> same?(state)
      sign("0 SEND #{asset} 4.1 #{alice.addr} #{bob.addr}", alice.priv)
      |> check_tx(state) |> fail?(1, 'malformed_numbers') |> same?(state)
      sign("0 SEND #{asset} 5 4 #{alice.addr} #{bob.addr}", alice.priv)
      |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
      
      # no signature
      create_send(nonce: 0, asset: asset, amount: 5, from: alice.addr, to: bob.addr)
      |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
    end
  end

  describe "generic nonce tests" do
    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "querying nonces", %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      query(state, '/nonces/#{alice.addr}') |> found?(0)

      %{state: state} =
        create_send(nonce: 0, asset: asset, amount: 5, from: alice.addr, to: bob.addr)
        |> sign(alice.priv) |> deliver_tx(state) |> success?

      query(state, '/nonces/#{bob.addr}') |> found?(0)
      query(state, '/nonces/#{alice.addr}') |> found?(1)
    end

    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "checking nonces", %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      create_send(nonce: 1, asset: asset, amount: 1, from: alice.addr, to: bob.addr)
      |> sign(alice.priv) |> check_tx(state) |> fail?(1, 'invalid_nonce') |> same?(state)
      
      %{state: state} = 
        create_send(nonce: 0, asset: asset, amount: 1, from: alice.addr, to: bob.addr)
        |> sign(alice.priv) |> deliver_tx(state) |> success?
        
      create_send(nonce: 0, asset: asset, amount: 1, from: alice.addr, to: bob.addr)
      |> sign(alice.priv) |> check_tx(state) |> fail?(1, 'invalid_nonce') |> same?(state)
      create_send(nonce: 2, asset: asset, amount: 1, from: alice.addr, to: bob.addr)
      |> sign(alice.priv) |> check_tx(state) |> fail?(1, 'invalid_nonce') |> same?(state)
      create_send(nonce: 1, asset: asset, amount: 1, from: alice.addr, to: bob.addr)
      |> sign(alice.priv) |> check_tx(state) |> success? |> same?(state)
    end

    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset, :some_block_hash]
    test "nonces common for all transaction types",
    %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset, some_block_hash: hash} do
      %{state: state} = 
        create_send(nonce: 0, asset: asset, amount: 1, from: alice.addr, to: bob.addr)
        |> sign(alice.priv) |> deliver_tx(state) |> success?

      # check transactions other than send
      create_create_token(nonce: 0, issuer: alice.addr)
      |> sign(alice.priv) |> check_tx(state) |> fail?(1, 'invalid_nonce') |> same?(state)
      create_issue(nonce: 0, asset: asset, amount: 5, dest: alice.addr, issuer: alice.addr)
      |> sign(alice.priv) |> check_tx(state) |> fail?(1, 'invalid_nonce') |> same?(state)
      create_send(nonce: 0, asset: asset, amount: 1, from: alice.addr, to: bob.addr)
      |> sign(alice.priv) |> check_tx(state) |> fail?(1, 'invalid_nonce') |> same?(state)
      create_sign_off(nonce: 0, height: 100, hash: hash, sender: alice.addr, signoffer: alice.addr)
      |> sign(alice.priv) |> check_tx(state) |> fail?(1, 'invalid_nonce') |> same?(state)
      create_allow(nonce: 0, allower: alice.addr, allowee: alice.addr, privilege: "signoff", allow: true)
      |> sign(alice.priv) |> check_tx(state) |> fail?(1, 'invalid_nonce') |> same?(state)
    end
  end

  describe "send transactions logic" do
    @tag fixtures: [:bob, :state_alice_has_tokens, :asset]
    test "bob has nothing (sanity)", %{state_alice_has_tokens: state, bob: bob, asset: asset} do
      query(state, '/accounts/#{asset}/#{bob.addr}') |> not_found?
    end

    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "correct transfer", %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      %{state: state} = 
        create_send(nonce: 0, asset: asset, amount: 1, from: alice.addr, to: bob.addr)
        |> sign(alice.priv) |> deliver_tx(state) |> success?
      query(state, '/accounts/#{asset}/#{bob.addr}') |> found?(1)
      query(state, '/accounts/#{asset}/#{alice.addr}') |> found?(4)
    end

    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "insufficient funds", %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      create_send(nonce: 0, asset: asset, amount: 6, from: alice.addr, to: bob.addr)
      |> sign(alice.priv) |> check_tx(state) |> fail?(1, 'insufficient_funds') |> same?(state)
    end

    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "negative amount", %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      sign("0 SEND #{asset} -1 #{alice.addr} #{bob.addr}", alice.priv)
      |> check_tx(state) |> fail?(1, 'positive_amount_required') |> same?(state)
    end

    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "zero amount", %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      sign("0 SEND #{asset} 0 #{alice.addr} #{bob.addr}", alice.priv)
      |> check_tx(state) |> fail?(1, 'positive_amount_required') |> same?(state)
    end

    @tag fixtures: [:bob, :carol, :state_alice_has_tokens, :asset]
    test "unknown sender", %{state_alice_has_tokens: state, bob: bob, carol: carol, asset: asset} do
      create_send(nonce: 0, asset: asset, amount: 1, from: carol.addr, to: bob.addr)
      |> sign(carol.priv) |> check_tx(state) |> fail?(1, 'insufficient_funds') |> same?(state)
    end

    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "second consecutive transfer", %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      %{state: state} =
        create_send(nonce: 0, asset: asset, amount: 1, from: alice.addr, to: bob.addr)
        |> sign(alice.priv) |> deliver_tx(state) |> success?
      %{state: state} = 
        create_send(nonce: 1, asset: asset, amount: 4, from: alice.addr, to: bob.addr)
        |> sign(alice.priv) |> deliver_tx(state) |> success?

      query(state, '/accounts/#{asset}/#{bob.addr}') |> found?(5)
      query(state, '/accounts/#{asset}/#{alice.addr}') |> found?(0)
    end

    @tag fixtures: [:alice, :bob, :state_alice_has_tokens, :asset]
    test "signature checking in send", %{state_alice_has_tokens: state, alice: alice, bob: bob, asset: asset} do
      {:ok, tx1} = create_send(nonce: 0, asset: asset, amount: 1, from: alice.addr, to: bob.addr)
      {:ok, tx2} = create_send(nonce: 0, asset: asset, amount: 4, from: alice.addr, to: bob.addr)
      {:ok, alice_signature} = HonteD.Crypto.sign(tx1, alice.priv)
      
      assert {:reply, {:ResponseCheckTx, 1, '', 'invalid_signature'}, ^state} =
        handle_call({:RequestCheckTx, "#{tx2} #{alice_signature}"}, nil, state)

      tx1 |> sign(bob.priv) |> check_tx(state) |> fail?(1, 'invalid_signature') |> same?(state)
    end
  end

  describe "well formedness of sign off transactions" do
    @tag fixtures: [:issuer, :empty_state, :some_block_hash]
    test "checking sign off transactions", %{empty_state: state, issuer: issuer, some_block_hash: hash} do
      create_sign_off(nonce: 0, height: 1, hash: hash, sender: issuer.addr) 
      |> sign(issuer.priv) |> check_tx(state) |> success? |> same?(state)

      # malformed
      sign("0 SIGN_OF 1 #{hash} #{issuer.addr} #{issuer.addr}", issuer.priv)
      |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
      sign("0 SIGN_OFF 1 2 #{hash} #{issuer.addr} #{issuer.addr}", issuer.priv)
      |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
      sign("0 SIGN_OFF #{hash} #{issuer.addr} #{issuer.addr}", issuer.priv)
      |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
      
      sign("0 SIGN_OFF 1.0 #{hash} #{issuer.addr} #{issuer.addr}", issuer.priv)
      |> check_tx(state) |> fail?(1, 'malformed_numbers') |> same?(state)
      
      # no signature
      create_sign_off(nonce: 0, height: 1, hash: hash, sender: issuer.addr)
      |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
    end

    @tag fixtures: [:alice, :issuer, :empty_state, :some_block_hash]
    test "signature checking in sign off", %{empty_state: state, alice: alice, issuer: issuer, some_block_hash: hash} do
      {:ok, tx1} = create_sign_off(nonce: 0, height: 1, hash: hash, sender: issuer.addr) 
      {:ok, tx2} = create_sign_off(nonce: 0, height: 2, hash: hash, sender: issuer.addr) 
      {:ok, issuer_signature} = HonteD.Crypto.sign(tx1, issuer.priv)
      
      assert {:reply, {:ResponseCheckTx, 1, '', 'invalid_signature'}, ^state} =
        handle_call({:RequestCheckTx, "#{tx2} #{issuer_signature}"}, nil, state)

      tx1 |> sign(alice.priv) |> check_tx(state) |> fail?(1, 'invalid_signature') |> same?(state)
    end

  end

  describe "sign off transactions logic," do
    @tag fixtures: [:bob, :empty_state]
    test "initial sign off (sanity)", %{empty_state: state, bob: bob} do
      query(state, '/sign_offs/#{bob.addr}') |> not_found?
    end

    @tag fixtures: [:bob, :empty_state, :some_block_hash]
    test "correct sign_offs", %{empty_state: state, bob: bob, some_block_hash: hash} do
      some_height = 100
      some_next_height = 200
      %{state: state} =
        create_sign_off(nonce: 0, height: some_height, hash: hash, sender: bob.addr)
        |> sign(bob.priv) |> deliver_tx(state) |> success?
      # FIXME: test querrying in T95
      %{state: _} =
        create_sign_off(nonce: 1, height: some_next_height, hash: String.reverse(hash), sender: bob.addr)
        |> sign(bob.priv) |> deliver_tx(state) |> success?
      # FIXME: as above
    end

    @tag fixtures: [:bob, :empty_state, :some_block_hash]
    test "can't sign_off into the past", %{empty_state: state, bob: bob, some_block_hash: hash} do
      some_height = 100
      some_previous_height = 50
      %{state: state} =
        create_sign_off(nonce: 0, height: some_height, hash: hash, sender: bob.addr)
        |> sign(bob.priv) |> deliver_tx(state) |> success?
      
      create_sign_off(nonce: 1, height: some_previous_height, hash: String.reverse(hash), sender: bob.addr)
      |> sign(bob.priv) |> check_tx(state) |> fail?(1, 'sign_off_not_incremental') |> same?(state)
      create_sign_off(nonce: 1, height: some_previous_height, hash: hash, sender: bob.addr)
      |> sign(bob.priv) |> check_tx(state) |> fail?(1, 'sign_off_not_incremental') |> same?(state)
    end
    
    @tag fixtures: [:alice, :bob, :empty_state, :some_block_hash]
    test "can't delegated-signoff if not allowed or dissalowed",
    %{empty_state: state, alice: alice, bob: bob, some_block_hash: hash} do
      create_sign_off(nonce: 0, height: 100, hash: hash, sender: bob.addr, signoffer: alice.addr)
      |> sign(bob.priv) |> check_tx(state) |> fail?(1, 'invalid_delegation') |> same?(state)
      
      %{state: state} =
        create_allow(nonce: 0, allower: alice.addr, allowee: bob.addr, privilege: "signoff", allow: true)
        |> sign(alice.priv) |> deliver_tx(state) |> success?
        
      create_sign_off(nonce: 0, height: 100, hash: hash, sender: bob.addr, signoffer: alice.addr)
      |> sign(bob.priv) |> check_tx(state) |> success? |> same?(state)
      
      %{state: state} =
        create_allow(nonce: 0, allower: alice.addr, allowee: bob.addr, privilege: "signoff", allow: false)
        |> sign(alice.priv) |> deliver_tx(state) |> success?
      
      create_sign_off(nonce: 0, height: 100, hash: hash, sender: bob.addr, signoffer: alice.addr)
      |> sign(bob.priv) |> check_tx(state) |> fail?(1, 'invalid_delegation') |> same?(state)
    end
    
    @tag fixtures: [:alice, :bob, :empty_state, :some_block_hash]
    test "sign-off delegation works only one way",
    %{empty_state: state, alice: alice, bob: bob, some_block_hash: hash} do
      %{state: state} =
        create_allow(nonce: 0, allower: bob.addr, allowee: alice.addr, privilege: "signoff", allow: true)
        |> sign(bob.priv) |> deliver_tx(state) |> success?
      
      create_sign_off(nonce: 1, height: 100, hash: hash, sender: bob.addr, signoffer: alice.addr)
      |> sign(bob.priv) |> check_tx(state) |> fail?(1, 'invalid_delegation') |> same?(state)
    end
    
    @tag fixtures: [:alice, :bob, :empty_state, :some_block_hash]
    test "sign-off delegation doesn't affect signature checking",
    %{empty_state: state, alice: alice, bob: bob, some_block_hash: hash} do
      %{state: state} =
        create_allow(nonce: 0, allower: alice.addr, allowee: bob.addr, privilege: "signoff", allow: true)
        |> sign(alice.priv) |> deliver_tx(state) |> success?
      
      create_sign_off(nonce: 1, height: 100, hash: hash, sender: alice.addr, signoffer: alice.addr)
      |> sign(bob.priv) |> check_tx(state) |> fail?(1, 'invalid_signature') |> same?(state)
    end
    
    @tag fixtures: [:alice, :empty_state, :some_block_hash]
    test "self sign-off delegation / revoking doesn't change anything",
    %{empty_state: state, alice: alice, some_block_hash: hash} do
      %{state: state} =
        create_allow(nonce: 0, allower: alice.addr, allowee: alice.addr, privilege: "signoff", allow: false)
        |> sign(alice.priv) |> deliver_tx(state) |> success?
        
      create_sign_off(nonce: 1, height: 100, hash: hash, sender: alice.addr)
      |> sign(alice.priv) |> check_tx(state) |> success? |> same?(state)
      
      %{state: state} =
        create_allow(nonce: 1, allower: alice.addr, allowee: alice.addr, privilege: "signoff", allow: true)
        |> sign(alice.priv) |> deliver_tx(state) |> success?
      
      create_sign_off(nonce: 2, height: 100, hash: hash, sender: alice.addr)
      |> sign(alice.priv) |> check_tx(state) |> success? |> same?(state)
    end
    
    @tag fixtures: [:bob, :empty_state, :some_block_hash]
    test "zero height", %{empty_state: state, bob: bob, some_block_hash: hash} do
      sign("0 SIGN_OFF 0 #{hash} #{bob.addr} #{bob.addr}", bob.priv)
      |> check_tx(state) |> fail?(1, 'positive_amount_required') |> same?(state)
    end
    
    @tag fixtures: [:bob, :empty_state, :some_block_hash]
    test "negative height", %{empty_state: state, bob: bob, some_block_hash: hash} do
      sign("0 SIGN_OFF -1 #{hash} #{bob.addr} #{bob.addr}", bob.priv)
      |> check_tx(state) |> fail?(1, 'positive_amount_required') |> same?(state)
    end
  end

  describe "well formedness of allow transactions," do
    @tag fixtures: [:issuer, :alice, :empty_state]
    test "checking allow transactions", %{empty_state: state, issuer: issuer, alice: alice} do
      create_allow(nonce: 0, allower: issuer.addr, allowee: alice.addr, privilege: "signoff", allow: true)
      |> sign(issuer.priv) |> check_tx(state) |> success?

      # malformed
      sign("0 ALLO #{issuer.addr} #{alice.addr} signoff true", issuer.priv)
      |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
      sign("0 ALLOW #{issuer.addr} #{alice.addr} signoff", issuer.priv)
      |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
      sign("0 ALLOW #{issuer.addr} #{alice.addr} signoff true true", issuer.priv)
      |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
      sign("0 ALLOW #{issuer.addr} #{alice.addr} signoff maybe", issuer.priv)
      |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
      
      # no signature
      create_allow(nonce: 0, allower: issuer.addr, allowee: alice.addr, privilege: "signoff", allow: true)
      |> check_tx(state) |> fail?(1, 'malformed_transaction') |> same?(state)
    end

    @tag fixtures: [:issuer, :alice, :empty_state]
    test "signature checking in allow", %{empty_state: state, issuer: issuer, alice: alice} do
      {:ok, tx1} = create_allow(nonce: 0, allower: issuer.addr, allowee: alice.addr, privilege: "signoff", allow: false)
      {:ok, tx2} = create_allow(nonce: 0, allower: issuer.addr, allowee: alice.addr, privilege: "signoff", allow: true)
      {:ok, issuer_signature} = HonteD.Crypto.sign(tx1, issuer.priv)
      
      assert {:reply, {:ResponseCheckTx, 1, '', 'invalid_signature'}, ^state} =
        handle_call({:RequestCheckTx, "#{tx2} #{issuer_signature}"}, nil, state)

      tx1 |> sign(alice.priv) |> check_tx(state) |> fail?(1, 'invalid_signature') |> same?(state)
    end
  end
  
  describe "allow transactions logic," do
    @tag fixtures: [:issuer, :alice, :empty_state]
    test "only restricted privileges", %{empty_state: state, issuer: issuer, alice: alice} do
      "0 ALLOW #{issuer.addr} #{alice.addr} signof true"
      |> sign(issuer.priv) |> check_tx(state) |> fail?(1, 'unknown_privilege') |> same?(state)
    end
  end
end
