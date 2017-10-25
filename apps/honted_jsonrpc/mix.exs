defmodule HonteDJSONRPC.Mixfile do
  use Mix.Project

  def project do
    [
      app: :honted_jsonrpc,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end
  
  def application do
    [
      env: [
        honted_api_rpc_port: 4000, # our own rpc port where HonteDAPI is exposed
        honted_api_ws_port: 4004, # our own websocket port where HonteDAPI is exposed
      ],
      extra_applications: [:logger],
      applications: [:jsonrpc2, :cowboy],
      mod: {HonteDJSONRPC.Application, []}
    ]
  end

  defp deps do
    [
      {:jsonrpc2, "~> 1.0"},
      {:cowboy, "~> 1.1"},
      {:poison, "~> 3.1"},
      #
      {:honted_api, in_umbrella: true},
    ]
  end
end
