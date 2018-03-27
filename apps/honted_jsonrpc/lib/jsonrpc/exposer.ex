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

defmodule HonteD.JSONRPC.Exposer do
  @moduledoc """
  This module contains a helper function to be called within JSONRPC Handlers `handle_request`

  It takes the original data request and channels it to a specific API exposed using HonteD.API.ExposeSpec

  Internally uses HonteD.API.ExposeSpec macro to expose function argument names
  so that pairing between JSON keys and arg names becomes possible.

  Note: it ignores extra args and does not yet handle functions
  of same name but different arity
  """

  @spec handle_request_on_api(method :: binary,
                              params :: %{required(binary) => any},
                              api :: atom) :: any
  def handle_request_on_api(method, params, api) do
    with {:ok, fname, args} <- HonteD.API.ExposeSpec.RPCTranslate.to_fa(method, params, api.get_specs()),
         {:ok, result} <- apply_call(api, fname, args)
    do
      result
    else
      error -> throw error # JSONRPC requires to throw whatever fails, for proper handling of jsonrpc errors
    end
  end

  defp apply_call(module, fname, args) do
    case apply(module, fname, args) do
      # NOTE: let's treat all error in the called API as internal errors, this seems legit
      {:ok, any} -> {:ok, any}
      {:error, any} -> {:internal_error, any}
    end
  end
end
