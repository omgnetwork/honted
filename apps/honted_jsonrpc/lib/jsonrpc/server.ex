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

defmodule HonteD.JSONRPC.Server.Handler do
  @moduledoc """
  Exposes HonteD.API via jsonrpc 2.0 over HTTP. It leverages the generic HonteD.JSONRPC.Exposer convenience module

  Only handles the integration with the JSONRPC2 package
  """
  use JSONRPC2.Server.Handler

  def handle_request(method, params) do
    HonteD.JSONRPC.Exposer.handle_request_on_api(method, params, HonteD.API)
  end

end
