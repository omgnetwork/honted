defmodule HonteD.Integration.Mixfile do
  use Mix.Project

  def project do
    [
      app: :honted_integration,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.5",
      start_permanent: false,
      deps: deps()
    ]
  end

  def application do
    :test = Mix.env # assertion
    [
      extra_applications: [:logger],
    ]
  end

  defp deps do
    [
      {:porcelain, "~> 2.0", only: :test},
      {:temp, "~> 0.4", only: :test},
      {:socket, "~> 0.3", only: :test},
      {:hackney, "~> 1.7", only: :test},
      #
      {:honted_api, in_umbrella: true},
      {:honted_abci, in_umbrella: true},
      {:honted_ws, in_umbrella: true},
      {:honted_jsonrpc, in_umbrella: true},
    ]
  end
end
