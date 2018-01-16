defmodule HonteD.Eth.Contract do
  @moduledoc """
  Ask staking contract for validator and epoch information.
  """
  import Ethereumex.HttpClient

  def block_height do
    {:ok, enc_answer} = eth_block_number()
    padded = mb_pad_16(enc_answer)
    {:ok, dec} = Base.decode16(padded, case: :lower)
    :binary.decode_unsigned(dec)
  end

  def read_validators(staking) do
    {:ok, current} = get_current_epoch(staking)
    {:ok, max_vals} = max_number_of_validators(staking)
    read_validators(staking, current, max_vals)
  end

  defp read_validators(staking, current_epoch, max_vals) when current_epoch > 0 do
    for epoch <- 1..current_epoch do
      get_while = fn(index, acc) -> wrap_while(acc, get_validator(staking, epoch, index)) end
      %{epoch: epoch, validators: Enum.reduce_while(0..max_vals, [], get_while)}
    end
  end
  defp read_validators(_staking, _current_epoch, _max_vals) do
    []
  end

  defp wrap_while(acc, {:ok, [{0, _tm_addr, _eth_addr}]}) do
    {:halt, acc}
  end
  defp wrap_while(acc, {:ok, [{_, _, _} = value]}) do
    {:cont, [value | acc]}
  end

  def get_validator(staking, epoch, index) do
    return_types = [{:tuple, [{:uint, 256}, :address, :address]}]
    call_contract(staking, "getValidator(uint256,uint256)", [epoch, index], return_types)
  end

  def in_maturity_margin?(staking) do
    current_height = block_height()
    {:ok, next} = get_next_epoch_block_number(staking)
    {:ok, mm} = maturity_margin(staking)
    current_height > (next - mm)
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

  def call_contract_value(staking, signature) do
    {:ok, [value]} = call_contract(staking, signature, [], [{:uint, 256}])
    {:ok, value}
  end

  def call_contract(contract, signature, args, return_types) do
    data = signature |> ABI.encode(args) |> Base.encode16
    {:ok, "0x" <> enc_return} = eth_call(%{to: contract, data: "0x#{data}"})
    decode_answer(enc_return, return_types)
  end

  def decode_answer(enc_return, return_types) do
    return =
      enc_return
      |> Base.decode16!(case: :lower)
      |> ABI.TypeDecoder.decode_raw(return_types)
    {:ok, return}
  end

  defp cleanup("0x" <> hex), do: hex |> String.upcase |> Base.decode16!
  defp cleanup(other), do: other

  def ether, do: trunc(:math.pow(10, 18))

  def eth_hex(num) when is_number(num) do
    hex = [trunc(num)]
      |> ABI.TypeEncoder.encode_raw([{:uint, 256}])
      |> Base.encode16(case: :lower)
    "0x" <> hex
  end

  def mb_pad_16("0x" <> hex) do
    len = trunc(bit_size(hex) / 8)
    evenodd = rem(len, 2)
    case evenodd do
      0 -> hex
      1 -> "0" <> hex
    end
  end
end
