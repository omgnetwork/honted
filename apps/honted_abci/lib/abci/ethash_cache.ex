defmodule HonteD.ABCI.EthashCache do
  use Rustler, otp_app: :honted_abci, crate: "ethashcache"

  def make_cache(_a), do: throw :nif_not_loaded
end
