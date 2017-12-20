defmodule HonteD.ABCI.Fixtures do
  # NOTE: we can't enforce this here, because of the keyword-list-y form of create_x calls
  # credo:disable-for-this-file Credo.Check.Refactor.PipeChainStart

  use ExUnitFixtures.FixtureModule

  import HonteD.Transaction

  import HonteD.ABCI.TestHelpers

  deffixture empty_state do
    {:ok, state} = HonteD.ABCI.init(:ok)
    state
  end

  deffixture entities do
    %{
      alice: generate_entity(),
      bob: generate_entity(),
      issuer: generate_entity(),
      issuer2: generate_entity(),
      carol: generate_entity(),
    }
  end

  deffixture alice(entities), do: entities.alice
  deffixture bob(entities), do: entities.bob
  deffixture carol(entities), do: entities.carol
  deffixture issuer(entities), do: entities.issuer
  deffixture issuer2(entities), do: entities.issuer2

  deffixture asset(state_with_token, issuer) do
    %{code: 0, value: [asset]} = query(state_with_token, '/issuers/#{issuer.addr}')
    asset
  end

  deffixture asset2(state_bob_has_tokens2, issuer2) do
    %{code: 0, value: [asset]} = query(state_bob_has_tokens2, '/issuers/#{issuer2.addr}')
    asset
  end

  deffixture state_with_token(empty_state, issuer) do
    %{code: 0, state: state} =
      create_create_token(nonce: 0, issuer: issuer.addr) |> sign(issuer.priv) |> deliver_tx(empty_state)
    %{state: state} = commit(state)
    state
  end

  deffixture state_alice_has_tokens(state_with_token, alice, issuer, asset) do
    %{code: 0, state: state} =
      create_issue(nonce: 1, asset: asset, amount: 5, dest: alice.addr, issuer: issuer.addr)
      |> sign(issuer.priv) |> deliver_tx(state_with_token)
    %{state: state} = commit(state)
    state
  end

  deffixture state_bob_has_tokens2(state_alice_has_tokens, bob, issuer2, asset2) do
    %{code: 0, state: state} =
      create_create_token(nonce: 0, issuer: issuer2.addr) |> sign(issuer2.priv)
      |> deliver_tx(state_alice_has_tokens)
    %{code: 0, state: state} =
      create_issue(nonce: 1, asset: asset2, amount: 5, dest: bob.addr, issuer: issuer2.addr)
      |> sign(issuer2.priv) |> deliver_tx(state)
    %{state: state} = commit(state)
    state
  end

  deffixture some_block_hash do
    "ABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCD"
  end
end
