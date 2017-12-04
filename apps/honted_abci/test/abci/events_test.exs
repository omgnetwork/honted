defmodule HonteD.ABCI.EventsTest do
  @moduledoc """
  Tests if Events are processed correctly, by the registered :honted_events app

  THis tests only the integration between ABCI and the Eventer GenServer, i.e. whether the events are emitted
  correctly. No HonteD.API.Events logic tested here
  """
  use ExUnitFixtures
  use ExUnit.Case, async: false  # modifies the ABCI's registered Eventer process

  import HonteD.Transaction

  import HonteD.API.TestHelpers
  import HonteD.ABCI.TestHelpers

  @test_eventer HonteD.API.Events.Eventer
  @timeout 100

  deffixture server_spawner() do
    # returns a function that spawns a process waiting for a particular expected message (or silence)
    # this is used to mock the Eventer GenServer
    # this process is registered in lieu of the Eventer, and should be `join`ed at the end of test
    # FIXME: this should be done in `on_exit` but it doesn't seem to work (assertions do not fail)
    # FIXME: consider using `Mox` to simulate receiving server. Reason: consistency
    fn expected_case ->
      # the following case determines the expected behavior of the spawned process
      server_pid = case expected_case do
        :expected_silence ->
          spawn_link(fn ->
            refute_receive(_, @timeout)
          end)
        expected_message ->
          spawn_link(fn ->
            assert_receive({:"$gen_cast", ^expected_message}, @timeout)
          end)
      end
      # plug the proces where the Eventer Genserver is expected
      Process.register(server_pid, @test_eventer)
      server_pid
    end
  end

  describe "ABCI and Eventer work together." do
    @tag fixtures: [:server_spawner, :empty_state, :issuer]
    test "create token transaction emits events", %{empty_state: state, issuer: issuer, server_spawner: server_spawner} do
      params = [nonce: 0, issuer: issuer.addr]
      server_pid = server_spawner.({
        :event,
        struct(HonteD.Transaction.CreateToken, params)})
      
      create_create_token(params) |> sign(issuer.priv) |> deliver_tx(state)
      join(server_pid)
    end
    
    @tag fixtures: [:server_spawner, :state_with_token, :alice, :asset, :issuer]
    test "issue transaction emits events", %{state_with_token: state, asset: asset, alice: alice, issuer: issuer,
                                             server_spawner: server_spawner} do
      params = [nonce: 1, asset: asset, amount: 5, dest: alice.addr, issuer: issuer.addr]
      server_pid = server_spawner.({
        :event,
        struct(HonteD.Transaction.Issue, params)})
      
      create_issue(params) |> sign(issuer.priv) |> deliver_tx(state)
      join(server_pid)
    end
    
    @tag fixtures: [:server_spawner, :state_alice_has_tokens, :alice, :bob, :asset]
    test "send transaction emits events", %{state_alice_has_tokens: state, asset: asset, alice: alice, bob: bob,
                                            server_spawner: server_spawner} do
      params = [nonce: 0, asset: asset, amount: 5, from: alice.addr, to: bob.addr]
      server_pid = server_spawner.({
        :event,
        struct(HonteD.Transaction.Send, params)})
      
      create_send(params) |> sign(alice.priv) |> deliver_tx(state)
      join(server_pid)
    end
    
    @tag fixtures: [:server_spawner, :state_with_token, :some_block_hash, :issuer, :alice, :asset]
    test "signoff transaction emits events with tokens", %{state_with_token: state, issuer: issuer, alice: alice,
                                                           some_block_hash: hash, server_spawner: server_spawner,
                                                           asset: asset} do
      %{state: state} = 
        create_allow(nonce: 1, allower: issuer.addr, allowee: alice.addr, privilege: "signoff", allow: true)
        |> sign(issuer.priv) |> deliver_tx(state)
      
      params = [nonce: 0, height: 1, hash: hash, sender: alice.addr, signoffer: issuer.addr]
      server_pid = server_spawner.({
        :event_context,
        struct(HonteD.Transaction.SignOff, params),
        [asset]
      })
      
      create_sign_off(params) |> sign(alice.priv) |> deliver_tx(state)
      join(server_pid)
    end
    
    @tag fixtures: [:server_spawner, :empty_state, :issuer, :alice]
    test "allow transaction emits events", %{empty_state: state, issuer: issuer, alice: alice,
                                             server_spawner: server_spawner} do
      params = [nonce: 0, allower: issuer.addr, allowee: alice.addr, privilege: "signoff", allow: true]
      server_pid = server_spawner.({
        :event,
        struct(HonteD.Transaction.Allow, params)})
      
      create_allow(params) |> sign(issuer.priv) |> deliver_tx(state)
      join(server_pid)
    end

    @tag fixtures: [:server_spawner, :empty_state, :some_block_hash, :issuer]
    test "correct tx doesn't emit on check tx", %{empty_state: state, issuer: issuer, some_block_hash: hash,
                                                  server_spawner: server_spawner} do
      params = [nonce: 0, height: 1, hash: hash, sender: issuer.addr]
      server_pid = server_spawner.(:expected_silence)
      
      create_sign_off(params) |> sign(issuer.priv) |> check_tx(state)
      join(server_pid)
    end

    @tag fixtures: [:server_spawner, :empty_state, :some_block_hash, :issuer]
    test "statefully incorrect tx doesn't emit", %{empty_state: state, issuer: issuer, some_block_hash: hash,
                                                   server_spawner: server_spawner} do
      params = [nonce: 1, height: 1, hash: hash, sender: issuer.addr]
      server_pid = server_spawner.(:expected_silence)
      # FIXME: deliver_tx should not crash here: this is intended version. Please restore
      #  next line after allowing :ResponseDeliverTx to return non-zero error codes.
      # create_sign_off(params) |> sign(issuer.priv) |> deliver_tx(state)
      raw_tx = create_sign_off(params) |> sign(issuer.priv)
      # FIXME: but deliver_tx still crashes and we want to be sure that nothing was emitted anyway:
      assert_raise(MatchError, fn() -> deliver_tx(raw_tx, state) end)
      join(server_pid)
    end

    @tag fixtures: [:server_spawner, :empty_state, :some_block_hash, :issuer]
    test "statelessly incorrect tx doesn't emit", %{empty_state: state, issuer: issuer, some_block_hash: hash,
                                               server_spawner: server_spawner} do
      params = [nonce: 0, height: 1, hash: hash, sender: issuer.addr]
      server_pid = server_spawner.(:expected_silence)

      # FIXME: deliver_tx should not crash here: this is intended version. Please restore
      #  next line after allowing :ResponseDeliverTx to return non-zero error codes.
      # create_sign_off(params) |> deliver_tx(state)

      raw_tx = create_sign_off(params)
      # FIXME: but deliver_tx still crashes and we want to be sure that nothing was emitted anyway:
      assert_raise(MatchError, fn() -> deliver_tx(raw_tx, state) end)
      join(server_pid)
    end

  end
end