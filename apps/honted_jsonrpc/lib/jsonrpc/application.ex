defmodule HonteD.JSONRPC.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    honted_port = Application.get_env(:honted_jsonrpc, :honted_api_rpc_port)
    children = [
      JSONRPC2.Servers.HTTP.child_spec(:http, HonteD.JSONRPC.Server.Handler,
                                       [port: honted_port])
    ]

    opts = [strategy: :one_for_one, name: HonteD.JSONRPC.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
