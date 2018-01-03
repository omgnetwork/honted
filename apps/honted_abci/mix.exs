defmodule HonteD.ABCI.Mixfile do
  use Mix.Project

  def project do
    [
      app: :honted_abci,
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

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      env: [
        abci_port: 46_658, # our own abci port tendermint connects to
      ],
      extra_applications: [:logger],
      applications: [:cowboy],
      mod: {HonteD.ABCI.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:abci_server, "~> 0.3.0", [github: 'KrzysiekJ/abci_server']},
      {:cowboy, "~> 1.1"},
      {:ranch, "~> 1.3.2"},
      {:ojson, "~> 1.0.0"},
      {:bimap, "~> 0.1.1"},
      {:poison, "~> 3.1"},
      {:ex_unit_fixtures, "~> 0.3.1", only: [:test]},
      #
      {:honted_lib, in_umbrella: true},
      {:honted_api, in_umbrella: true},
    ]
  end
end
