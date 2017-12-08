defmodule HonteD.ABCI.Record.Helper do
  @moduledoc """
  You can import all records from particular hrl file into your module using this helper.
  To do that define a @lib module attribute like this:
  `@lib "abci_server/include/abci.hrl"`
  Next, add `use HonteD.ABCI.Record.Helper`

  Note! All record names will be processed with Macro.underscore/1, but original tags will
  be preserved in the runtime.
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
