Code.load_file("test/abci_helpers.ex")

defmodule HonteD.ABCI.ABCIFixtures do
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
      carol: generate_entity(),
    }
  end

  deffixture alice(entities), do: entities.alice
  deffixture bob(entities), do: entities.bob
  deffixture carol(entities), do: entities.carol
  deffixture issuer(entities), do: entities.issuer

  deffixture asset(issuer) do
    # FIXME: as soon as that functionality lands, we should use HonteD.API to discover newly created
    # token addresses
    # (multiple occurrences!)
    HonteD.Token.create_address(issuer.addr, 0)
  end

  deffixture state_with_token(empty_state, issuer) do
    %{code: 0, state: state} =
      create_create_token(nonce: 0, issuer: issuer.addr) |> sign(issuer.priv) |> deliver_tx(empty_state)
    state
  end

  deffixture state_alice_has_tokens(state_with_token, alice, issuer, asset) do
    %{code: 0, state: state} =
      create_issue(nonce: 1, asset: asset, amount: 5, dest: alice.addr, issuer: issuer.addr)
      |> sign(issuer.priv) |> deliver_tx(state_with_token)
    state
  end

  deffixture some_block_hash() do
    "ABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCD"
  end


end
