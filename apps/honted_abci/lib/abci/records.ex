defmodule HonteD.ABCI.Records do
  @moduledoc """
    Convenience^WClarity wrapper for abci_server's Erlang records.
  """

  require Record
  import Record, only: [defrecord: 3, extract: 2]

  @lib "abci_server/include/abci.hrl"

  defrecord :request_end_block, :"RequestEndBlock", extract(:"RequestEndBlock", from_lib: @lib)
  defrecord :response_end_block, :"ResponseEndBlock", extract(:"ResponseEndBlock", from_lib: @lib)

  defrecord :request_begin_block, :"RequestBeginBlock", extract(:"RequestBeginBlock", from_lib: @lib)
  defrecord :response_begin_block, :"ResponseBeginBlock", extract(:"ResponseBeginBlock", from_lib: @lib)
  defrecord :header, :"Header", extract(:"Header", from_lib: @lib)

  defrecord :request_info, :"RequestInfo", extract(:"RequestInfo", from_lib: @lib)
  defrecord :response_info, :"ResponseInfo", extract(:"ResponseInfo", from_lib: @lib)

  defrecord :block_id, :"BlockID", extract(:"BlockID", from_lib: @lib)
end
