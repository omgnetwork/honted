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
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      env: [
        abci_port: 46658, # our own abci port tendermint connects to
      ],
      extra_applications: extras(Mix.env),
      applications: [:cowboy],
      mod: {HonteD.ABCI.Application, []}
    ]
  end

  defp extras(:dev), do: extras(:all) ++ [:remix]
  defp extras(_all), do: [:logger, :honted_events]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:abci_server, github: 'KrzysiekJ/abci_server'},
      {:cowboy, "~> 1.1"},
      {:ranch, "~> 1.3.2"},
      {:ojson, "~> 1.0.0"},
      {:bimap, "~> 0.1.1"},
      {:ex_unit_fixtures, "~> 0.3.1", only: [:test]},
      {:remix, "~> 0.0.1", only: [:dev]},
      #
      {:honted_lib, in_umbrella: true},
      {:honted_events, in_umbrella: true},
    ]
  end
end
