defmodule HonteD.Validator do
  defstruct [:stake,
             :tendermint_address,
            ]

  def validator(stake, tendermint_address) when is_integer(stake) do
    %HonteD.Validator{stake: stake, tendermint_address: tendermint_address}
  end

end
