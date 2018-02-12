defmodule HonteD.Integration.TendermintCompatibilityTest do
  @moduledoc """
  Testing various compatibilities with tendermint core

  """

  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias HonteD.{Crypto, API}

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
    {:ok, signature} = Crypto.sign(raw_tx, issuer_priv)
    tx = raw_tx <> " " <> signature

    {:ok, %{tx_hash: hash}} = tx |> API.submit_commit()
    assert hash == API.Tendermint.Tx.hash(tx)
  end
end
