Code.load_file("../honted_api/test/testlib/api/api_helpers.ex")

defmodule HonteD.ABCI.EventsTest do
  @moduledoc """
  Tests if Events are processed correctly, by the registered :honted_events app
  
  FIXME: think if we shouldn't test using a fixture-provided Eventer GenServer as in HonteD.API-HonteD.Events.Eventer
         tests. That would allow `async: true`
  """
  use ExUnitFixtures
  use ExUnit.Case, async: false

  import HonteD.Transaction
  import HonteD.Events

  import HonteD.API.TestHelpers
  import HonteD.ABCI.TestHelpers
  
  @test_eventer HonteD.Events.Eventer

  deffixture server do
    {:ok, _} = GenServer.start(HonteD.Events.Eventer, [], [name: @test_eventer])
  end

  defp receivable({:ok, something}), do: receivable(something)
  defp receivable(binary) when is_binary(binary) do
    {:ok, decoded} = HonteD.TxCodec.decode(binary)
    receivable(decoded)
  end
  defp receivable(%HonteD.Transaction.SignedTx{raw_tx: rtx}), do: receivable(rtx)
  defp receivable(decoded), do: receivable_for(decoded)

  describe "ABCI and Eventer work together." do
    @tag fixtures: [:server, :state_alice_has_tokens, :some_block_hash, :alice, :bob, :asset, :issuer]
    test "Sign_off delivers :finalized events.", %{state_alice_has_tokens: state, asset: asset,
                                                   alice: alice, bob: bob,
                                                   issuer: issuer, some_block_hash: hash} do
      # prepare send
      {:ok, send_enc} = create_send(nonce: 0, asset: asset, amount: 5, from: alice.addr, to: bob.addr)
      e1 = receivable(sign(send_enc, alice.priv))
      e2 = receivable_finalized(e1)
      {:ok, signoff_enc} = create_sign_off(nonce: 2, height: 2, hash: hash, sender: issuer.addr)
      pid = client(fn() ->
        assert_receive(^e1)
        assert_receive(^e2)
        refute_receive(_)
      end)
      new_send_filter(@test_eventer, pid, bob.addr)
      assert status_send_filter?(@test_eventer, pid, bob.addr)
      {:ok, send_enc} |> sign(alice.priv) |> deliver_tx(state) |> success?
      {:ok, signoff_enc} |> sign(issuer.priv) |> deliver_tx(state) |> success?
      join()
    end
  end
end
