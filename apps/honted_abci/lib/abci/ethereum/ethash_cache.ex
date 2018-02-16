defmodule HonteD.ABCI.Ethereum.EthashCache do
  @moduledoc """
  Creates cache for Ethash
  """
  use Rustler, otp_app: :honted_abci, crate: "ethashcache"

  @dialyzer {:nowarn_function, __init__: 0} # supress warning in __init__ function in Rustler macro

  @doc """
  Returns cache used for constructing Ethereum DAG
  """
  def make_cache(_a), do: :erlang.nif_error(:nif_not_loaded)

end
