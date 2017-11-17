defmodule HonteD.Integration.APITest do
  
  use ExUnitFixtures
  use ExUnit.Case, async: false
  
  alias HonteD.{Crypto, API}

  @startup_timeout 20000
  @supply 5
  
  deffixture homedir() do
    {:ok, dir_path} = Temp.mkdir("tendermint")
    on_exit fn ->
      {:ok, _} = File.rm_rf(dir_path)
    end
    dir_path
  end
  
  deffixture tendermint(homedir, honted) do
    # we just depend on honted running, so match to prevent compiler woes
    :ok = honted
    
    %Porcelain.Result{err: nil, status: 0} = Porcelain.shell(
      "tendermint --home #{homedir} init"
    )
    
    # start tendermint and capture the stdout
    tendermint_proc = %Porcelain.Process{err: nil, out: tendermint_out} = Porcelain.spawn_shell(
      "tendermint --home #{homedir} --log_level \"*:info\" node",
      out: :stream,
    )
    :ok = 
      fn -> wait_for_tendermint_start(tendermint_out) end
      |> Task.async
      |> Task.await(@startup_timeout)
      
    on_exit fn -> 
      Porcelain.Process.stop(tendermint_proc)
    end
  end
  
  deffixture honted() do
    started_apps = 
      [:honted_api, :honted_abci, :honted_ws, :honted_jsonrpc, :honted_events]
      |> Enum.map(&Application.ensure_all_started/1)
      |> Enum.flat_map(fn {:ok, app_list} -> app_list end)
    on_exit fn -> 
      started_apps
      |> Enum.map(&Application.stop/1)
    end
    :ok
  end
  
  defp wait_for_tendermint_start(outstream) do
    # monitors the stdout coming out of Tendermint for singal of successful startup
    outstream
    |> Stream.take_while(fn line -> not String.contains?(line, "Started node") end)
    |> Enum.to_list
    :ok
  end
  
  defmodule TestWebsocket do
    def connect!() do
      Socket.Web.connect!("localhost", 4004)
    end
    
    def send!(websocket, method, params) when is_atom(method) and is_map(params) do
      encoded_message = Poison.encode!(%{wsrpc: "1.0", type: :rq, method: method, params: params})
      websocket
      |> Socket.Web.send!({
        :text,
        encoded_message
      })
    end
    
    def recv!(websocket) do
      {:text, response} = Socket.Web.recv!(websocket)
      case Poison.decode!(response) do
        %{"result" => decoded_result, "type" => "rs", "wsrpc" => "1.0"} -> decoded_result
        %{"source" => source} = event when source in ["filter"] -> event
        %{"error" => decoded_error, "type" => "rs", "wsrpc" => "1.0"} -> {:error, decoded_error}
      end
    end
    
    @doc """
    Trick play to coerce the results to form as given by external apis (e.g. strings instead of atoms for keys)
    """
    def codec(term) do
      term
      |> Poison.encode!
      |> Poison.decode!
    end
  end
  
  deffixture websocket do
    TestWebsocket.connect!()
  end
  
  @tag :integration
  @tag fixtures: [:tendermint, :websocket]
  test "demo smoke test", %{websocket: websocket} do
    # FIXME: dry this setup?
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
    
    # check consistency of api exposers
    TestWebsocket.send!(websocket, :create_create_token_transaction, %{issuer: issuer})
    assert raw_tx == TestWebsocket.recv!(websocket)
    
    {:ok, signature} = Crypto.sign(raw_tx, issuer_priv)
    full_transaction = raw_tx <> " " <> signature
    
    assert {:ok,
      %{
        committed_in: _,
        duplicate: false,
        tx_hash: some_hash
      }
    } = API.submit_transaction(full_transaction)
    
    # dupliacte
    assert {:ok,
      %{
        committed_in: nil,
        duplicate: true,
        tx_hash: ^some_hash
      } = submit_result
    } = API.submit_transaction(full_transaction)
     
    # check consistency of api exposers
    TestWebsocket.send!(websocket, :submit_transaction, %{transaction: full_transaction})
    assert TestWebsocket.codec(submit_result) == TestWebsocket.recv!(websocket)
     
    # sane invalid transaction response
    assert {:error,
      %{
        code: 1,
        data: "",
        log: "malformed_transaction",
        reason: :check_tx_failed,
        tx_hash: _
      }
    } = API.submit_transaction(raw_tx)
    
    assert {:ok, [asset]} = API.tokens_issued_by(issuer)
    
    TestWebsocket.send!(websocket, :tokens_issued_by, %{issuer: issuer})
    assert [asset] == TestWebsocket.recv!(websocket)
    
    {:ok, raw_tx} = API.create_issue_transaction(asset, @supply, alice, issuer)
    
    # check consistency of api exposers
    TestWebsocket.send!(websocket, 
                        :create_issue_transaction,
                        %{asset: asset, amount: @supply, to: alice, issuer: issuer})
    assert raw_tx == TestWebsocket.recv!(websocket)
    
    {:ok, signature} = Crypto.sign(raw_tx, issuer_priv)
    {:ok, _ } = API.submit_transaction(raw_tx <> " " <> signature)
    
    # wait

    assert {:ok, @supply} = API.query_balance(asset, alice)
    assert {:ok,
      %{
        issuer: ^issuer,
        token: ^asset,
        total_supply: @supply
      }
    } = API.token_info(asset)
    
    TestWebsocket.send!(websocket, :query_balance, %{token: asset, address: alice})
    assert @supply == TestWebsocket.recv!(websocket)
    
    # FIXME: execute and check using this test
    # query token info using json rpc
    # http --json localhost:4000 method=token_info params:='{"token": ""}' jsonrpc=2.0 id=1
    
    # subscribe to filter
    TestWebsocket.send!(websocket, :new_send_filter, %{watched: bob})
    assert "ok" == TestWebsocket.recv!(websocket)
    
    {:ok, raw_tx} = API.create_send_transaction(asset, 5, alice, bob)
    
    # check consistency of api exposers
    TestWebsocket.send!(websocket, 
                        :create_send_transaction,
                        %{asset: asset, amount: 5, from: alice, to: bob})
    assert raw_tx == TestWebsocket.recv!(websocket)
    
    {:ok, signature} = Crypto.sign(raw_tx, alice_priv)
    {:ok, %{tx_hash: hash}} = API.submit_transaction(raw_tx <> " " <> signature)
    
    # check event
    assert %{
      "transaction" => %{
        "amount" => 5,
        "asset" => asset,
        "from" => alice,
        "nonce" => 0,
        "to" => bob
      },
      "type" => "committed"
    } = TestWebsocket.recv!(websocket)

    assert {
      :ok,
      %{
        :status => :committed, 
        "height" => _, 
        "index" => _,
        "proof" => _,
        "tx" => decoded_tx,
        "tx_result" => %{"code" => 0, "data" => "", "log" => ""}
      } = tx_query_result
    } = API.tx(hash)
    
    TestWebsocket.send!(websocket, :tx, %{hash: hash})
    assert TestWebsocket.codec(tx_query_result) == TestWebsocket.recv!(websocket)
    
    assert String.starts_with?(decoded_tx, "0 SEND #{asset} 5 #{alice} #{bob}")
    
    assert {
      :ok,
      %{
        issuer: ^issuer,
        token: ^asset,
        total_supply: @supply
      } = token_info_query_result
    } = API.token_info(asset)
    
    TestWebsocket.send!(websocket, :token_info, %{token: asset})
    assert TestWebsocket.codec(token_info_query_result) == TestWebsocket.recv!(websocket)
    
    # FIXME: demo_03.md contents
  end
  
  @tag :integration
  @tag fixtures: [:tendermint, :websocket]
  test "incorrect calls to websockets should return sensible response not crash", %{websocket: websocket} do
    # bad method
    TestWebsocket.send!(websocket, :token_inf, %{token: ""})
    {:error, %{"data" => %{"method" => "token_inf"}, "message" => "Method not found"}} = TestWebsocket.recv!(websocket)
    
    # bad params
    TestWebsocket.send!(websocket, :token_info, %{toke: ""})
    {:error, %{"data" => %{"msg" => "Please provide parameter `token` of type `:binary`",
                           "name" => "token",
                           "type" => "binary"
                         },
               "message" => "Invalid params"}
     } = TestWebsocket.recv!(websocket)
  end
end
