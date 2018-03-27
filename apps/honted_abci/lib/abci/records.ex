#   Copyright 2018 OmiseGO Pte Ltd
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

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
