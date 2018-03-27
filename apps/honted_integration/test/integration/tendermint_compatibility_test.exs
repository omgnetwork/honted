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

defmodule HonteD.Integration.TendermintCompatibilityTest do
  @moduledoc """
  Testing various compatibilities with tendermint core

  """

  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias HonteD.{Crypto, API, Transaction}

  @moduletag :integration

  @doc """
  Tests compatibility of hashes between tendermint tx hashing and our implementation

  NOTE: ideally this shouldn't be needed at all, but we need to recalculate these hashes as consistent event references
  """
  @tag fixtures: [:tendermint]
  test "tendermint tx hash", %{} do
    {:ok, issuer_priv} = Crypto.generate_private_key()
    {:ok, issuer_pub} = Crypto.generate_public_key(issuer_priv)
    {:ok, issuer} = Crypto.generate_address(issuer_pub)

    {:ok, raw_tx} = API.create_create_token_transaction(issuer)
    signed_tx = Transaction.sign(raw_tx, issuer_priv)

    {:ok, %{tx_hash: hash}} = API.submit_commit(signed_tx)
    assert hash == signed_tx |> Base.decode16!() |> API.Tendermint.Tx.hash()
  end
end
