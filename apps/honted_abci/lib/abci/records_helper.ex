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

defmodule HonteD.ABCI.Record.Helper do
  @moduledoc """
  You can import all records from particular hrl file into your module using this helper.
  To do that define a @lib module attribute like this:
  `@lib "abci_server/include/abci.hrl"`
  Next, add `use HonteD.ABCI.Record.Helper`

  NOTE All record names will be processed with Macro.underscore/1, but original tags will
  be preserved in the runtime.
  NOTE due to problems with Excoveralls checking coverage in macros calling macros (see below)
  we are skipping this file's coverage in honted_abci/coveralls.json, see D333
  """
  require Record
  import Record, only: [defrecord: 3, extract_all: 1]

  defmacro __using__(_opts) do
    quote do
      import HonteD.ABCI.Record.Helper

      @before_compile HonteD.ABCI.Record.Helper
    end
  end

  defmacro __before_compile__(env) do
    module = env.module
    lib = Module.get_attribute(module, :lib)
    for {tag, fields} <- extract_all(from_lib: lib) do
      name =
        case is_binary(tag) do
          false -> tag |> Atom.to_string |> Macro.underscore |> String.to_atom
          true -> tag |> Macro.underscore |> String.to_atom
        end
      quote do
        defrecord unquote(name), unquote(tag), unquote(fields)
      end
    end
  end
end
