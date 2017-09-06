defmodule HonteD.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      :abci_server.child_spec(HonteD, 46658),
      {HonteD, name: HonteD}
      # Starts a worker by calling: HonteD.Worker.start_link(arg)
      # {HonteD.Worker, arg},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HonteD.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
