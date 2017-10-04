Application.ensure_all_started(:hackney)

defmodule HonteD.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      :abci_server.child_spec(HonteD.ABCI, 46658),
      {HonteD.ABCI, name: HonteD.ABCI},
      JSONRPC2.Servers.HTTP.child_spec(:http, HonteD.JSONRPC2.Server.Handler)
    ]

    opts = [strategy: :one_for_one, name: HonteD.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
