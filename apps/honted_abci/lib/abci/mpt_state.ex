defmodule HonteD.ABCI.MPTState do
  @moduledoc """
  Utility functions for state stored in Merkle Patricia Tree
  """
  alias MerklePatriciaTree.Trie

  #TODO: do not encode value types, remove when ABCI is ready for that
  @encoded_bool "b"
  @encoded_int "i"
  @encoded_sign_off "s"
  @encoded_default "d"

  defp hash_key(key), do: HonteD.Crypto.hash(key)

  defp decode_integer(bytes) when is_binary(bytes), do: :binary.decode_unsigned(bytes)

  defp encode_boolean(boolean) when is_boolean(boolean), do: Atom.to_string(boolean)

  defp decode_boolean(value), do: String.to_existing_atom(value)

  def get(state, key) do
    hashed_key = hash_key(key)
    case MerklePatriciaTree.Trie.get(state, hashed_key) do
      [@encoded_bool, val] -> decode_boolean(val)
      [@encoded_int, val] -> decode_integer(val)
      [@encoded_sign_off, [height, hash]] -> %{height: decode_integer(height), hash: hash}
      [@encoded_default, val] -> val
      _ -> nil
    end
  end

  def put(state, key, %{height: height, hash: hash}) do
    do_put(state, key, [height, hash], fn v -> [@encoded_sign_off, v] end)
  end
  def put(state, key, value) when is_boolean(value),
    do: do_put(state, key, value, fn v -> [@encoded_bool, encode_boolean(v)] end)
  def put(state, key, value) when is_integer(value) do
     do_put(state, key, value, fn v -> [@encoded_int, v] end)
  end
  def put(state, key, value), do: do_put(state, key, value, fn v -> [@encoded_default, v] end)

  defp do_put(state, key, value, encode_value) do
    hashed_key = hash_key(key)
    Trie.update(state, hashed_key, encode_value.(value))
  end

  def update!(state, key, update) do
    old_value = get(state, key)
    put(state, key, update.(old_value))
    case get(state, key) do
      nil -> raise KeyError
      old_value -> put(state, key, update.(old_value))
    end
  end

  def update(state, key, default, update) do
    case get(state, key) do
      nil -> put(state, key, default)
      old_value -> put(state, key, update.(old_value))
    end
  end

end
