Application.ensure_all_started(:hackney)

defmodule HonteD.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    abci_port = Application.get_env(:honted, :abci_port)
    honted_port = Application.get_env(:honted, :honted_api_rpc_port)
    children = [
      :abci_server.child_spec(HonteD.ABCI, abci_port),
      {HonteD.ABCI, name: HonteD.ABCI},
      JSONRPC2.Servers.HTTP.child_spec(:http, HonteD.JSONRPC2.Server.Handler,
                                       [port: honted_port])
    ]

    opts = [strategy: :one_for_one, name: HonteD.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
