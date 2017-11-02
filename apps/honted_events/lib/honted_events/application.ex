defmodule HonteDEvents.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {HonteDEvents.Eventer, name: HonteDEvents.Eventer},
    ]

    opts = [strategy: :one_for_one, name: HonteDEvents.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
