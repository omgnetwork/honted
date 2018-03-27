#   Copyright 2018 OmiseGO Pte Ltd
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

defmodule HonteD.ABCI.Fixtures do
  # NOTE: we can't enforce this here, because of the keyword-list-y form of create_x calls
  # credo:disable-for-this-file Credo.Check.Refactor.PipeChainStart

  use ExUnitFixtures.FixtureModule

  import HonteD.Transaction
  import HonteD.ABCI.TestHelpers

  deffixture staking_state do
    %HonteD.Staking{
      ethereum_block_height: 10,
      start_block: 0,
      epoch_length: 2,
      maturity_margin: 1
    }
  end

  deffixture empty_state(staking_state) do
    {:ok, state} = HonteD.ABCI.init([staking_state])
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
      create_create_token(nonce: 0, issuer: issuer.addr) |> encode_sign(issuer.priv) |> deliver_tx(empty_state)
    %{state: state} = commit(state)
    state
  end

  deffixture state_alice_has_tokens(state_with_token, alice, issuer, asset) do
    %{code: 0, state: state} =
      create_issue(nonce: 1, asset: asset, amount: 5, dest: alice.addr, issuer: issuer.addr)
      |> encode_sign(issuer.priv) |> deliver_tx(state_with_token)
    %{state: state} = commit(state)
    state
  end

  deffixture state_bob_has_tokens2(state_alice_has_tokens, bob, issuer2, asset2) do
    %{code: 0, state: state} =
      create_create_token(nonce: 0, issuer: issuer2.addr) |> encode_sign(issuer2.priv)
      |> deliver_tx(state_alice_has_tokens)
    %{code: 0, state: state} =
      create_issue(nonce: 1, asset: asset2, amount: 5, dest: bob.addr, issuer: issuer2.addr)
      |> encode_sign(issuer2.priv) |> deliver_tx(state)
    %{state: state} = commit(state)
    state
  end

  deffixture some_block_hash do
    "ABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCD"
  end

  deffixture state_no_epoch_change(empty_state, staking_state) do
    staking_state_no_epoch_change = %{staking_state | ethereum_block_height: 0}
    {:noreply, state} =
      HonteD.ABCI.handle_cast({:set_staking_state, staking_state_no_epoch_change}, empty_state)
    state
  end

end
