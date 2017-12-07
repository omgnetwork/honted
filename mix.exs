defmodule HonteD.Umbrella.Mixfile do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      dialyzer: [ flags: [:error_handling, :race_conditions, :underspecs, :unknown, :unmatched_returns],
                  plt_add_deps: :transitive,
                  ignore_warnings: "dialyzer.ignore-warnings"
                ],
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:mox, "~> 0.3.1", only: :test},
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
    ]
  end
end
