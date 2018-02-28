defmodule HonteD.ABCI.Paths do
  @moduledoc """
  State is a key-value store. This module defines how binary keys are constructed.
  """

  def key_nonces(address), do: prefix_address(1, address)
  def key_issued_tokens(address), do: prefix_address(2, address)
  def key_token_issuer(token_addr), do: prefix_address(3, token_addr)
  def key_token_supply(token_addr), do: prefix_address(4, token_addr)
  def key_signoffs(sender), do: prefix_address(5, sender)
  def key_delegations(allower, allowee, privilege) when is_atom(privilege) do
    privilege = Atom.to_string(privilege)
    key_delegations(allower, allowee, privilege)
  end
  def key_delegations(allower, allowee, privilege) do
    <<6 :: integer-size(8), allower :: binary-size(20), allowee :: binary-size(20), privilege :: binary>>
  end
  def key_asset_ownership(asset, owner) do
    <<7 :: integer-size(8), asset :: binary-size(20), owner :: binary-size(20)>>
  end

  defp prefix_address(prefix, address) do
    <<prefix :: integer-size(8), address :: binary-size(20)>>
  end

end
