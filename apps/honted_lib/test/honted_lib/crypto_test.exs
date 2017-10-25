defmodule HonteDLib.CryptoTest do
  use ExUnit.Case, async: true
  @moduledoc """
  Consider removing if brittle - testing implementation details
  
  A sanity check of the crypto-placeholder implementation
  """
  test "wrap unwrap sign verify" do
    {:ok, priv} = HonteDLib.Crypto.generate_private_key
    {:ok, pub} = HonteDLib.Crypto.generate_public_key(priv)
    {:ok, address} = HonteDLib.Crypto.generate_address(pub)
    
    {:ok, signature} = HonteDLib.Crypto.sign("message", priv)
    assert {:ok, true} == HonteDLib.Crypto.verify("message", signature, address)
    assert {:ok, false} == HonteDLib.Crypto.verify("message2", signature, address)
  end
  
end
