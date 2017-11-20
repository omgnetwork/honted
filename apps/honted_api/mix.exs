defmodule HonteD.API.Mixfile do
  use Mix.Project

  def project do
    [
      app: :honted_api,
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
        rpc_port: 46657, # tendermint node's rpc port
      ],
      extra_applications: [:logger],
      applications: [:honted_events] ++ do_test_applications(),
    ]
  end
  
  defp do_test_applications do
    if Mix.env == :test, do: [:porcelain, :hackney], else: []
  end

  defp deps do
    [
      {:tesla, "~>0.8.0"},
      {:plug, "~> 1.3"},
      {:poison, "~> 3.1"},
      {:porcelain, "~> 2.0", only: :test},
      {:temp, "~> 0.4", only: :test},
      {:socket, "~> 0.3", only: :test},
      {:hackney, "~> 1.7", only: :test},
      #
      {:honted_lib, in_umbrella: true},
      {:honted_events, in_umbrella: true},
    ]
  end
end
