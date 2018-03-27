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

defmodule HonteD.ABCI.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    abci_port = Application.get_env(:honted_abci, :abci_port)
    children = [
      {HonteD.ABCI, name: HonteD.ABCI},
      :abci_server.child_spec(HonteD.ABCI, abci_port),
    ]

    opts = [strategy: :one_for_one, name: HonteD.ABCI.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
