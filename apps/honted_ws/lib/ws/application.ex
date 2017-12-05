defmodule HonteD.WS.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      HonteD.WS.Server,
    ]

    opts = [strategy: :one_for_one, name: HonteD.WS.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
