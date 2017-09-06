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
      extra_applications: extra_applications(Mix.env),
      mod: {HonteD.Application, []}
    ]
  end

  defp extra_applications(:dev), do: extra_applications(:all) ++ [:remix]
  defp extra_applications(_all), do: [:logger]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:abci_server, github: 'KrzysiekJ/abci_server'},
      {:ranch, github: 'ninenines/ranch'},
      {:remix, "~> 0.0.1", only: :dev}
    ]
  end
end
