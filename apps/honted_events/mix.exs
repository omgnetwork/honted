defmodule HonteDEvents.Mixfile do
  use Mix.Project

  def project do
    [
      app: :honted_events,
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
      ],
      extra_applications: [:logger],
      applications: [],
      mod: {HonteDEvents.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bimap, "~> 0.1.1"},
      {:ex_unit_fixtures, "~> 0.3.1", only: [:test]},
    ]
  end
end
