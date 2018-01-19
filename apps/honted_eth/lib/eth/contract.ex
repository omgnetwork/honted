defmodule HonteD.Eth.Contract do
  @moduledoc """
  Ask staking contract for validator and epoch information.
  """

  @behaviour HonteD.Eth.ContractBehavior

  require Integer

  def block_height do
    {:ok, "0x" <> enc_answer} = Ethereumex.HttpClient.eth_block_number()
    padded = pad_to_even(enc_answer)
    {:ok, dec} = Base.decode16(padded, case: :lower)
    :binary.decode_unsigned(dec)
  end

  @spec syncing? :: boolean()
  def syncing? do
    try do
      sync = Ethereumex.HttpClient.eth_syncing()
      case sync do
        {:ok, syncing} when is_boolean(syncing) -> syncing
        {:ok, _} -> true
      end
    catch
      _other ->
        true
      _class, _type ->
        true
    end
  end

  def read_validators(staking) do
    {:ok, current} = get_current_epoch(staking)
    {:ok, max_vals} = max_number_of_validators(staking)
    read_validators(staking, current, max_vals)
  end

  defp read_validators(staking, current_epoch, max_vals) when current_epoch > 0 do
    # Validators will be there since epoch 1; for epoch 0 we get set of validators from genesis file.
    kv = for epoch <- 1..current_epoch do
      get_while = fn(index, acc) -> wrap_while(acc, get_validator(staking, epoch, index)) end
      {epoch, Enum.reduce_while(0..max_vals, [], get_while)}
    end
    Map.new(kv)
  end
  defp read_validators(_staking, _current_epoch, _max_vals) do
    []
  end

  defp wrap_while(acc, {:ok, [{0, _tm_pubkey, _eth_addr} = _value]}) do
    {:halt, acc}
  end
  defp wrap_while(acc, {:ok, [{stake, tm_pubkey_raw, _} = _value]}) do
    tm_pubkey = tm_pubkey_raw |> Base.encode16(case: :upper)
    {:cont, [%HonteD.Validator{:stake => stake, :tendermint_address => tm_pubkey} | acc]}
  end

  def get_validator(staking, epoch, index) do
    return_types = [{:tuple, [{:uint, 256}, :bytes32, :address]}]
    call_contract(staking, "getValidator(uint256,uint256)", [epoch, index], return_types)
  end

  def balance_of(token, address) do
    signature = "balanceOf(address)"
    {:ok, [value]} = call_contract(token, signature, [cleanup(address)], [{:uint, 256}])
    {:ok, value}
  end

  def get_current_epoch(staking) do
    call_contract_value(staking, "getCurrentEpoch()")
  end

  def get_next_epoch_block_number(staking) do
    call_contract_value(staking, "getNextEpochBlockNumber()")
  end

  def safety_limit_for_validators(staking) do
    call_contract_value(staking, "safetyLimitForValidators()")
  end

  def max_number_of_validators(staking) do
    call_contract_value(staking, "maxNumberOfValidators()")
  end

  def maturity_margin(staking) do
    call_contract_value(staking, "maturityMargin()")
  end

  def epoch_length(staking) do
    call_contract_value(staking, "epochLength()")
  end

  def start_block(staking) do
    call_contract_value(staking, "startBlock()")
  end

  def unbonding_period(staking) do
    call_contract_value(staking, "unbondingPeriod()")
  end

  defp call_contract_value(staking, signature) do
    {:ok, [value]} = call_contract(staking, signature, [], [{:uint, 256}])
    {:ok, value}
  end

  defp call_contract(contract, signature, args, return_types) do
    data = signature |> ABI.encode(args) |> Base.encode16
    {:ok, "0x" <> enc_return} =
      Ethereumex.HttpClient.eth_call(%{to: contract, data: "0x#{data}"})
    decode_answer(enc_return, return_types)
  end

  defp decode_answer(enc_return, return_types) do
    return =
      enc_return
      |> Base.decode16!(case: :lower)
      |> ABI.TypeDecoder.decode_raw(return_types)
    {:ok, return}
  end

  defp cleanup("0x" <> hex), do: hex |> String.upcase |> Base.decode16!
  defp cleanup(other), do: other

  defp pad_to_even(hex) do
    case Integer.is_odd(byte_size(hex)) do
      false -> hex
      true -> "0" <> hex
    end
  end
end
