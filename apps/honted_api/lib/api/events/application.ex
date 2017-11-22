defmodule HonteD.API.Events.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {HonteD.API.Events.Eventer, name: HonteD.API.Events.Eventer},
    ]

    opts = [strategy: :one_for_one, name: HonteD.API.Events.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
