defmodule HonteD.ABCI.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    abci_port = Application.get_env(:honted_abci, :abci_port)
    children = [
      {HonteD.ABCI, name: HonteD.ABCI},
      :abci_server.child_spec(HonteD.ABCI, abci_port),
    ]

    opts = [strategy: :one_for_one, name: HonteD.ABCI.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
