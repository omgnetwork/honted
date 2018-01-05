defmodule HontedEth.Mixfile do
  use Mix.Project

  def project do
    [
      app: :honted_eth,
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
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:abi, "~> 0.1.6"},
      {:ethereumex, "~> 0.2.0"},
      {:porcelain, "~> 2.0"},
    ]
  end
end
