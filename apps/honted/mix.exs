defmodule HonteD.Mixfile do
  use Mix.Project

  def project do
    [
      app: :honted,
      version: "0.1.0",
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
      extra_applications: [:logger],
      applications: [:plug, :cowboy, :hackney],
      mod: {HonteD.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:abci_server, github: 'KrzysiekJ/abci_server'},
      {:ranch, "~> 1.3.2"},
      {:poison, "~> 3.1"},
      {:plug, "~> 1.3"},
      {:hackney, "~> 1.7"},
      {:ojson, "~> 1.0.0"},
      {:bimap, "~> 0.1.1"},
      {:ex_unit_fixtures, "~> 0.3.1", only: [:test]},
    ]
  end
end
