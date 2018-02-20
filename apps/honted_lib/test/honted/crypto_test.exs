defmodule HonteD.CryptoTest do
  use ExUnit.Case, async: true
  @moduledoc """
  Consider removing if brittle - testing implementation details

  A sanity check of the crypto-placeholder implementation
  """

  alias HonteD.Crypto

  test "library signature verify" do
    priv = :crypto.strong_rand_bytes(32)
    {:ok, pub} = ExthCrypto.Signature.get_public_key(priv)
    msg = :crypto.strong_rand_bytes(32)
    {signature, _r, _s, _recovery_id} =
      ExthCrypto.Signature.sign_digest(msg, priv)
    assert ExthCrypto.Signature.verify(msg, signature, pub)
  end

  test "library signature recover" do
    priv = :crypto.strong_rand_bytes(32)
    {:ok, pub} = ExthCrypto.Signature.get_public_key(priv)
    msg = :crypto.strong_rand_bytes(32)
    {signature, _r, _s, recovery_id} =
      ExthCrypto.Signature.sign_digest(msg, priv)
    assert {:ok, ^pub} = ExthCrypto.Signature.recover(msg, signature, recovery_id)
  end

  test "digest signature" do
    {:ok, priv} = Crypto.generate_private_key
    {:ok, pub} = Crypto.generate_public_key(priv)
    msg = :crypto.strong_rand_bytes(32)
    sig = Crypto.signature_digest(msg, priv)
    assert {:ok, ^pub} = Crypto.recover(msg, sig)
  end

  test "wrap unwrap sign verify" do
    {:ok, priv} = Crypto.generate_private_key
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, address} = Crypto.generate_address(pub)

    signature = Crypto.signature("message", priv)
    assert byte_size(signature) == 65
    assert {:ok, true} == Crypto.verify("message", signature, address)
    assert {:ok, false} == Crypto.verify("message2", signature, address)
  end

end
