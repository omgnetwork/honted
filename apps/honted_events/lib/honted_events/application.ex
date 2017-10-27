Application.ensure_all_started(:hackney)

defmodule HonteDEvents.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {HonteDEventer, name: HonteDEventer},
    ]

    opts = [strategy: :one_for_one, name: HonteD.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
