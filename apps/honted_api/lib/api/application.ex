defmodule HonteD.API.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {HonteD.API.Events.Eventer, name: HonteD.API.Events.Eventer},
      {HonteD.API.Tendermint.RPC.Websocket, name: HonteD.API.Tendermint.RPC.Websocket}
    ]

    opts = [strategy: :one_for_one, name: HonteD.API.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
