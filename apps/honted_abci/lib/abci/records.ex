defmodule HonteD.ABCI.Records do
  @moduledoc """
    Convenience and clarity wrapper for abci_server's Erlang records.

    Helper used below generates record definition macros that look like this:
    `defrecord :response_check_tx, :ResponseCheckTx, [code: 0, data: "", log: [], gas: 0, fee: 0]`

    Defrecord macros are generated during the compilation. As a next step Elixir's Record replaces
    those macros with its own magic. For source material (Erlang code generated automatically
    from Protocol Buffers definition) see `abci_server/include/abci.hrl` and `abci_server/src/abci.erl`.
  """

  @lib "abci_server/include/abci.hrl"
  use HonteD.ABCI.Record.Helper

end
