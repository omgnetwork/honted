defmodule HonteD.Validator do
  defstruct [:stake,
             :tendermint_address,
             :ethereum_address,
            ]

  def validator({stake, tm_addr, eth_addr}) when is_integer(stake) do
    %HonteD.Validator{stake: stake, tendermint_address: tm_addr, ethereum_address: eth_addr}
  end

end
