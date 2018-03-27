#   Copyright 2018 OmiseGO Pte Ltd
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

defmodule HonteD.Eth.Mixfile do
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
