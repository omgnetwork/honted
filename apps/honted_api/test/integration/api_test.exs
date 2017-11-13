defmodule HonteD.Integration.APITest do
  
  use ExUnitFixtures
  use ExUnit.Case, async: true
  
  alias HonteD.{Crypto, API}
  
  @supply 5
  
  deffixture homedir() do
    {:ok, dir_path} = Temp.mkdir("tendermint")
    on_exit fn ->
      {:ok, _} = File.rm_rf(dir_path)
    end
    dir_path
  end
  
  deffixture tendermint(homedir) do
    %Porcelain.Result{err: nil, status: 0} = Porcelain.shell("tendermint --home #{homedir} init")
    %Porcelain.Process{err: nil, out: _outstream} = Porcelain.spawn_shell(
      "tendermint --home #{homedir} --log_level \"*:info\" node"
    )
    :ok = Application.ensure_started(:honted_abci)
    # FIXME: WIP: how to change to timeouted-waiting for Tendermint to start running?
    # _ = 
    #   outstream
    #   |> Stream.take_while(fn line -> String.contains?(line, "Started node") end)
    #   |> Enum.to_list
    Process.sleep(5000)
    :ok
  end
  
  @tag :integration
  @tag fixtures: [:tendermint]
  test "demo smoke test" do
    {:ok, issuer_priv} = Crypto.generate_private_key()
    {:ok, issuer_pub} = Crypto.generate_public_key(issuer_priv)
    {:ok, issuer} = Crypto.generate_address(issuer_pub)
    
    {:ok, alice_priv} = Crypto.generate_private_key()
    {:ok, alice_pub} = Crypto.generate_public_key(alice_priv)
    {:ok, alice} = Crypto.generate_address(alice_pub)
    
    {:ok, bob_priv} = Crypto.generate_private_key()
    {:ok, bob_pub} = Crypto.generate_public_key(bob_priv)
    {:ok, bob} = Crypto.generate_address(bob_pub)

    {:ok, raw_tx} = API.create_create_token_transaction(issuer)
    {:ok, signature} = Crypto.sign(raw_tx, issuer_priv)
    {:ok,
     %{
       committed_in: _,
       duplicate: false,
       tx_hash: some_hash}
     } = API.submit_transaction(raw_tx <> " " <> signature)
    
    # dupliacte
    {:ok,
     %{
       committed_in: nil,
       duplicate: true,
       tx_hash: ^some_hash}
     } = API.submit_transaction(raw_tx <> " " <> signature)
     
     # sane invalid transaction response
    {:error,
      %{
        code: 1,
        data: "",
        log: "malformed_transaction",
        reason: :check_tx_failed,
        tx_hash: _
      }
    } = API.submit_transaction(raw_tx <> " ")
    
    {:ok, [asset]} = API.tokens_issued_by(issuer)
    
    {:ok, raw_tx} = API.create_issue_transaction(asset, @supply, alice, issuer)
    {:ok, signature} = Crypto.sign(raw_tx, issuer_priv)
    {:ok, _ } = API.submit_transaction(raw_tx <> " " <> signature)
    
    # wait

    {:ok, @supply} = API.query_balance(asset, alice)
    {:ok,
      %{
        issuer: ^issuer,
        token: ^asset,
        total_supply: @supply
      }
    } = API.token_info(asset)
    
    # FIXME: execute and check using this test
    # query balance using websockets
    # {"wsrpc": "1.0", "type": "rq", "method": "query_balance", "params": {"token": "", "address": ""}}
    # query issued tokens using websockets
    # {"wsrpc": "1.0", "type": "rq", "method": "tokens_issued_by", "params": {"issuer": ""}}
    # query token info using json rpc
    # http --json localhost:4000 method=token_info params:='{"token": ""}' jsonrpc=2.0 id=1
    
    # subscribe to filter
    # {"wsrpc": "1.0", "type": "rq", "method": "new_send_filter", "params": {"watched": ""}}
    
    {:ok, raw_tx} = API.create_send_transaction(asset, 5, alice, bob)
    {:ok, signature} = Crypto.sign(raw_tx, alice_priv)
    {:ok, %{tx_hash: hash}} = API.submit_transaction(raw_tx <> " " <> signature)

    {
      :ok,
      %{
        :decoded_tx => decoded_tx,
        :status => :committed, 
        "height" => _, 
        "index" => _,
        "proof" => _,
        "tx" => _,
        "tx_result" => %{"code" => 0, "data" => "", "log" => ""}
      }
    } = API.tx(hash)
    
    assert String.starts_with?(decoded_tx, "0 SEND #{asset} 5 #{alice} #{bob}")
    
    # FIXME: demo_03.md contents
  end
end
