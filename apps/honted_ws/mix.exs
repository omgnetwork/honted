defmodule HonteD.WS.Mixfile do
  use Mix.Project

  def project do
    [
      app: :honted_ws,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
    ]
  end

  def application do
    [
      env: [
        honted_api_ws_port: 4004, # our own ws port where HonteD.API is exposed
      ],
      extra_applications: [:logger],
      mod: {HonteD.WS.Application, []}
    ]
  end

  defp deps do
    [
      {:cowboy, "~> 1.1"},
      {:poison, "~> 3.1"},
      #
      {:honted_api, in_umbrella: true},
    ]
  end
end
