defmodule HonteD.Events.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {HonteD.Events.Eventer, name: HonteD.Events.Eventer},
    ]

    opts = [strategy: :one_for_one, name: HonteD.Events.Supervisor]
    Supervisor.start_link(children, opts)
  end
end