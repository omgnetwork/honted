defmodule HonteD.Eth.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {HonteD.Eth, name: HonteD.Eth},
    ]

    opts = [strategy: :one_for_one, name: HonteD.Eth.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
