defmodule CryptoTest do
  use ExUnit.Case, async: true
  @moduledoc """
  Consider removing if brittle - testing implementation details

  A sanity check of the crypto-placeholder implementation
  """

  alias HonteD.Crypto

  test "wrap unwrap sign verify" do
    {:ok, priv} = Crypto.generate_private_key
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, address} = Crypto.generate_address(pub)

    {:ok, signature} = Crypto.sign("message", priv)
    assert {:ok, true} == Crypto.verify("message", signature, address)
    assert {:ok, false} == Crypto.verify("message2", signature, address)
  end

end
