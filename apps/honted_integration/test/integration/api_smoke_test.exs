defmodule HonteD.Integration.ApiTest do
  @moduledoc """
  Check submit_* functions of API behave as expected.
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias HonteD.{Crypto, API}

  @moduletag :integration

  @tag fixtures: [:tendermint]
  test "check if apis are callable" do
    {:ok, issuer_priv} = Crypto.generate_private_key()
    {:ok, issuer_pub} = Crypto.generate_public_key(issuer_priv)
    {:ok, issuer} = Crypto.generate_address(issuer_pub)

    # submit_commit should do CheckTx and fail
    {:ok, raw_tx} = API.create_create_token_transaction(issuer)
    no_signature_tx = raw_tx
    assert {:error, %{reason: :check_tx_failed}} = API.submit_commit(no_signature_tx)

    # submit_sync should do CheckTx and fail
    assert {:error, %{reason: :submit_failed}} = API.submit_sync(no_signature_tx)

    # submit_async does no checks, should return tx id and indicate success
    assert {:ok, %{tx_hash: hash}} = API.submit_async(no_signature_tx)
    assert {:error, _} = API.tx(hash)

    token_creation = fn() ->
      {:ok, raw_tx} = API.create_create_token_transaction(issuer)
      {:ok, signature} = Crypto.sign(raw_tx, issuer_priv)
      raw_tx <> " " <> signature
    end

    # submit_commit succeeds
    assert {:ok, %{tx_hash: hash}} = token_creation.() |>  API.submit_commit()
    :timer.sleep(1000)
    assert {:ok, _} = API.tx(hash)

    # submit_sync does checkTx and succeeds
    assert {:ok, %{tx_hash: _}} = token_creation.() |> API.submit_sync()

    # submit_async does mempool membership check, should return error here
    assert {:error, _} = token_creation.() |> API.submit_async()

    :timer.sleep(2000)
    # submit_async does not do full checkTx end, should return tx id
    assert {:ok, %{tx_hash: hash}} = token_creation.() |> API.submit_async()
    # tx should be mined after some time
    :timer.sleep(2000)
    assert {:ok, _} = API.tx(hash)
  end
end
