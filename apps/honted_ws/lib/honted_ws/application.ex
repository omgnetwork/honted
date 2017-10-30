defmodule HonteDWS.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do  
    children = [
      HonteDWS.RPC,
    ]
    
    opts = [strategy: :one_for_one, name: HonteDWS.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
