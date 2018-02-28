defmodule HonteD.ABCI.State.ProcessRegistryDB do
  @moduledoc """
  Implementation of MerklePatriciaTree.DB which
  is backed by a map stored in process registry.
  This implementation allows efficient copying of MerklePatriciaTree.Trie.
  """
  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.DB

  @behaviour MerklePatriciaTree.DB

  @spec init(DB.db_name) :: DB.db
  def init(db_name) do
    Process.put(db_name, %{})
    {__MODULE__, db_name}
  end

  @spec get(DB.db_ref, Trie.key) :: {:ok, DB.value} | :not_found
  def get(db_name, key) do
    state = Process.get(db_name)
    case Map.fetch(state, key) do
      {:ok, v} -> {:ok, v}
      :error -> :not_found
    end
  end

  @spec put!(DB.db_ref, Trie.key, DB.value) :: :ok
  def put!(db_name, key, value) do
    state = Process.get(db_name)
    updated_state = Map.put(state, key, value)
    Process.put(db_name, updated_state)
    :ok
  end

  @doc """
  Copies a database by overriding process dictionary entry
  """
  @spec copy_db(DB.db_name, DB.db_name) :: :ok
  def copy_db(db_name, copy_name) do
    Process.delete(copy_name)
    copy = Process.get(db_name)
    Process.put(copy_name, copy)
    :ok
  end

end
