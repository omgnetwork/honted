defmodule HonteD.ABCI.MPTState do
  @moduledoc """
  Utility functions for state stored in Merkle Patricia Tree
  """
  alias MerklePatriciaTree.Trie

  @encoded_bool "b"
  @encoded_int "i"
  @encoded_sign_off "s"
  @encoded_default "d"

  defp hash_key(key), do: :keccakf1600.sha3_256(key)

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

  def set(state, key, %{height: height, hash: hash}) do
    do_set(state, key, [height, hash], fn v -> [@encoded_sign_off, v] end)
  end
  def set(state, key, value) when is_boolean(value),
    do: do_set(state, key, value, fn v -> [@encoded_bool, encode_boolean(v)] end)
  def set(state, key, value) when is_integer(value) do
     do_set(state, key, value, fn v -> [@encoded_int, v] end)
  end
  def set(state, key, value), do: do_set(state, key, value, fn v -> [@encoded_default, v] end)

  defp do_set(state, key, value, encode_value) do
    hashed_key = hash_key(key)
    Trie.update(state, hashed_key, encode_value.(value))
  end

  def update(state, key, update) do
    old_value = get(state, key)
    set(state, key, update.(old_value))
  end

  def update(state, key, default, update) do
    case get(state, key) do
      nil -> set(state, key, default)
      old_value -> set(state, key, update.(old_value))
    end
  end

  def copy_state(%Trie{db: {ProcessRegistryDB, db_name}, root_hash: root_hash},
                 %Trie{db: {ProcessRegistryDB, copy_name}} = copy) do
    :ok = ProcessRegistryDB.copy_db(db_name, copy_name)
    %{copy | root_hash: root_hash}
  end

end
