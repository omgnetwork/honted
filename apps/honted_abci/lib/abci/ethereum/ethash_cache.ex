defmodule HonteD.ABCI.Ethereum.EthashCache do
  @moduledoc """
  Creates cache for Ethash
  """
  use Rustler, otp_app: :honted_abci, crate: "ethashcache"

  @doc """
  Returns cache used for constructing Ethereum DAG
  """
  @spec make_cache(integer()) :: list(list(non_neg_integer()))
  def make_cache(_a), do: throw :nif_not_loaded
end
