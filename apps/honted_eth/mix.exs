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
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      env: [
        enabled: false, # set to true to fetch validator set state from Ethereum
        staking_contract_address: "0x0", # address of deployed staking address on Ethereum
      ],
      extra_applications: [:logger],
      mod: {HonteD.Eth.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:abi, git: "https://github.com/omisego/abi.git", branch: "add_bytes32"},
      {:ethereumex, git: "https://github.com/omisego/ethereumex.git", branch: "fix_spec", override: true},
      {:porcelain, "~> 2.0"},
    ]
  end
end
