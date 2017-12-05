defmodule HonteD.CryptoTest do
  use ExUnit.Case, async: true
  @moduledoc """
  Consider removing if brittle - testing implementation details

  A sanity check of the crypto-placeholder implementation
  """
  test "wrap unwrap sign verify" do
    {:ok, priv} = HonteD.Crypto.generate_private_key
    {:ok, pub} = HonteD.Crypto.generate_public_key(priv)
    {:ok, address} = HonteD.Crypto.generate_address(pub)

    {:ok, signature} = HonteD.Crypto.sign("message", priv)
    assert {:ok, true} == HonteD.Crypto.verify("message", signature, address)
    assert {:ok, false} == HonteD.Crypto.verify("message2", signature, address)
  end

end
