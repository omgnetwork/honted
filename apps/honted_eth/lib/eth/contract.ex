defmodule HonteD.Eth.Contract do
  @moduledoc """
  Ask staking contract for validator and epoch information.
  """
  import Ethereumex.HttpClient
  alias HonteD.Eth.WaitFor, as: WaitFor

  def deploy(epoch_length, maturity_margin, max_validators) do
    {:ok, [addr | _]} = eth_accounts()
    token = File.read!("contracts/omg_token_bytecode.hex")
    {:ok, token_address} = deploy_contract(addr, token, [], [])
    {:ok, staking_address} = deploy_contract(addr, staking_bytecode(),
      [epoch_length, maturity_margin, token_address, max_validators],
      [{:uint, 256}, {:uint, 256}, :address, {:uint, 256}])
    {:ok, token_address, staking_address}
  end

  defp deploy_contract(addr, bytecode, types, args) do
    enc_args = encode_constructor_params(types, args)
    four_mil = "0x3D0900"
    {:ok, txhash} = eth_send_transaction(%{from: addr, data: "0x" <> bytecode <> enc_args, gas: four_mil})
    {:ok, receipt} = WaitFor.receipt(txhash, 10_000)
    %{"contractAddress" => contract_address} = receipt
    {:ok, contract_address}
  end

  defp encode_constructor_params(args, types) do
    args = for arg <- args, do: cleanup(arg)
    args
    |> ABI.TypeEncoder.encode_raw(types)
    |> Base.encode16(case: :lower)
  end

  defp cleanup("0x" <> hex), do: hex |> String.upcase |> Base.decode16!
  defp cleanup(other), do: other

  defp staking_bytecode do
    %{"HonteStaking" => %{"bytecode" => bytecode}} =
      "populus/build/contracts.json"
      |> File.read!()
      |> Poison.decode!()
    String.replace(bytecode, "0x", "")
  end
end
