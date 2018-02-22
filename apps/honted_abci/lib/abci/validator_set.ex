defmodule HonteD.ABCI.ValidatorSet do
  @moduledoc """
  All internal handling of the tendermint validator set here
  """
  import HonteD.ABCI.Records
  alias HonteD.Validator

  @doc """
  Produces an ABCI-compatible slashing (removing) diff from evidence reported from Tendermint via ABCI
  """
  def diff_from_slash(nil), do: [] # in the absence of evidence, don't slash anyone
  def diff_from_slash(byzantine_validators) do
    byzantine_validators
    |> Enum.map(fn evidence(pub_key: pub_key) -> validator(pub_key: pub_key, power: 0) end)
  end

  @doc """
  Produces an ABCI-compatible diff using two different sets of validators from the staking contract
  """
  def diff_from_epoch(current_epoch_validators, next_epoch_validators) do
    removed_validators = removed_validators(current_epoch_validators, next_epoch_validators)
    next_validators = next_validators(next_epoch_validators)

    (removed_validators ++ next_validators)
  end

  @doc """
  Converts abci's representation of a validator to our internal structure (compatible with staking utilities)
  """
  def abci2staking_validator(validator(power: power, pub_key: pub_key)) do
    %Validator{stake: power, tendermint_address: encode_pub_key(pub_key)}
  end

  defp removed_validators(current_epoch_validators, next_epoch_validators) do
    removed_validators =
      tendermint_addresses(current_epoch_validators) -- tendermint_addresses(next_epoch_validators)
    Enum.map(removed_validators,
             fn tm_addr -> validator(pub_key: decode_pub_key(tm_addr), power: 0) end)
  end

  defp tendermint_addresses(validators), do: Enum.map(validators, &(&1.tendermint_address))

  defp next_validators(validators) do
    Enum.map(validators,
            fn %Validator{stake: stake, tendermint_address: tendermint_address} ->
              validator(pub_key: decode_pub_key(tendermint_address), power: stake)
            end)
  end

  # NOTE: <<1>> in this decode/encode functions, is tendermint/crypto's EC type 0x01, the only one we support now
  #       c.f. HonteStaking.sol function join
  defp decode_pub_key(pub_key), do: <<1>> <> Base.decode16!(pub_key)

  defp encode_pub_key(<<1>> <> pub_key), do: Base.encode16(pub_key)

end
