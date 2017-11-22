defmodule HonteD.Integration.SmokeTest do
  @moduledoc """
  Smoke tests the integration of abci/ws/jsonrpc/elixir_api/eventer applications in the wild
  
  FIXME: Main test is just one blob off tests taken from demos - consider engineering here
  FIXME: In case API unit test come to existence, consider removing some of these tests here and becoming more targetted
  """
  
  use ExUnitFixtures
  use ExUnit.Case, async: false
  
  alias HonteD.{Crypto, API}

  @startup_timeout 20000
  @supply 5
  
  @moduletag :integration
  
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
    # handles a setup/teardown of our apps, that talk to similarly setup/torndown tendermint instances
    our_apps_to_start = [:honted_api, :honted_abci, :honted_ws, :honted_jsonrpc]
    started_apps = 
      our_apps_to_start
      |> Enum.map(&Application.ensure_all_started/1)
      |> Enum.flat_map(fn {:ok, app_list} -> app_list end) # check if successfully started here!
    on_exit fn -> 
      started_apps
      |> Enum.map(&Application.stop/1)
    end
    :ok
  end
  
  defp wait_for_tendermint_start(outstream) do
    # monitors the stdout coming out of Tendermint for signal of successful startup
    outstream
    |> Stream.take_while(fn line -> not String.contains?(line, "Started node") end)
    |> Enum.to_list
    :ok
  end
  
  defmodule TestWebsocket do
    @moduledoc """
    A Websocket client used to test the honted_ws server
    """
    def connect!() do
      ws_port = Application.get_env(:honted_ws, :honted_api_ws_port)
      Socket.Web.connect!("localhost", ws_port)
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
        %{"result" => decoded_result, "type" => "rs", "wsrpc" => "1.0"} -> {:ok, decoded_result}
        %{"source" => source} = event when source in ["filter"] -> event
        %{"error" => decoded_error, "type" => "rs", "wsrpc" => "1.0"} -> {:error, decoded_error}
      end
    end
    
    @doc """
    Merges both above functions to send query and immediately fetch the response that comes in in next
    """
    def sendrecv!(websocket, method, params) when is_atom(method) and is_map(params) do
      :ok = TestWebsocket.send!(websocket, method, params)
      TestWebsocket.recv!(websocket)
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
  
  deffixture jsonrpc do
    jsonrpc_port = Application.get_env(:honted_jsonrpc, :honted_api_rpc_port)
    fn (method, params) ->
      JSONRPC2.Clients.HTTP.call("http://localhost:#{jsonrpc_port}", to_string(method), params)
      |> case do
        # JSONRPC Client returns the result in a specific format. We need to bring to common format with WS client
        {:error, {code, message, data}} -> {:error, %{"code" => code, "message" => message, "data" => data}}
        other_result -> other_result
      end
    end
  end
  
  deffixture apis_caller(websocket, jsonrpc) do
    # convenience function to check if calls to both apis are at least the same
    fn (method, params) ->
      resp1 = TestWebsocket.sendrecv!(websocket, method, params)
      resp2 = jsonrpc.(method, params)
      assert resp1 == resp2
      resp1
    end
  end
  
  @tag fixtures: [:tendermint, :websocket, :apis_caller]
  test "demo smoke test", %{websocket: websocket, apis_caller: apis_caller} do
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
    
    # CREATING TOKENS
    {:ok, raw_tx} = API.create_create_token_transaction(issuer)
    
    # check consistency of api exposers
    assert {:ok, raw_tx} == apis_caller.(:create_create_token_transaction, %{issuer: issuer})
    
    # TRANSACTION SUBMISSIONS
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
    assert {:ok, TestWebsocket.codec(submit_result)} == 
      apis_caller.(:submit_transaction, %{transaction: full_transaction})
     
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
    
    # LISTING TOKENS
    assert {:ok, [asset]} = API.tokens_issued_by(issuer)
    
    # check consistency of api exposers
    assert {:ok, [asset]} == apis_caller.(:tokens_issued_by, %{issuer: issuer})
    
    # ISSUEING
    {:ok, raw_tx} = API.create_issue_transaction(asset, @supply, alice, issuer)
    
    # check consistency of api exposers
    assert {:ok, raw_tx} == apis_caller.(
      :create_issue_transaction,
      %{asset: asset, amount: @supply, to: alice, issuer: issuer}
    )
    
    {:ok, signature} = Crypto.sign(raw_tx, issuer_priv)
    {:ok, _ } = API.submit_transaction(raw_tx <> " " <> signature)

    assert {:ok, @supply} = API.query_balance(asset, alice)
    
    # check consistency of api exposers
    assert {:ok, @supply} == apis_caller.(:query_balance, %{token: asset, address: alice})
    
    # EVENTS & Send TRANSACTION
    # subscribe to filter
    assert {:ok, "ok"} == TestWebsocket.sendrecv!(websocket, :new_send_filter, %{watched: bob})
    
    {:ok, raw_tx} = API.create_send_transaction(asset, 5, alice, bob)
    
    # check consistency of api exposers
    assert {:ok, raw_tx} == apis_caller.(
      :create_send_transaction,
      %{asset: asset, amount: 5, from: alice, to: bob}
    )
    
    {:ok, signature} = Crypto.sign(raw_tx, alice_priv)
    {:ok, %{tx_hash: hash, committed_in: send_height}} = API.submit_transaction(raw_tx <> " " <> signature)
    
    # check event
    assert %{
      "transaction" => %{
        "amount" => 5,
        "asset" => ^asset,
        "from" => ^alice,
        "nonce" => 0,
        "to" => ^bob
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
    
    # check consistency of api exposers
    assert {:ok, TestWebsocket.codec(tx_query_result)} == apis_caller.(:tx, %{hash: hash})
    
    # readable form of transactions in response
    assert String.starts_with?(decoded_tx, "0 SEND #{asset} 5 #{alice} #{bob}")
    
    # TOKEN INFO
    assert {
      :ok,
      %{
        issuer: ^issuer,
        token: ^asset,
        total_supply: @supply
      } = token_info_query_result
    } = API.token_info(asset)
    
    # check consistency of api exposers
    assert {:ok, TestWebsocket.codec(token_info_query_result)} == apis_caller.(:token_info, %{token: asset})

    # ALLOWS
    
    # {:ok, raw_tx} = API.create_allow_transaction(issuer, bob, "signoff", true)
    # 
    # # check consistency of api exposers
    # assert {:ok, raw_tx} == apis_caller.(
    #   :create_allow_transaction,
    #   %{allower: issuer, allowee: bob, privilege: "signoff", allow: true}
    # )
    # 
    # {:ok, signature} = Crypto.sign(raw_tx, bob_priv)
    # {:ok, _ } = API.submit_transaction(raw_tx <> " " <> signature)
    
    # SIGNOFF
    
    {:ok, hash} = API.Tools.get_block_hash(send_height)
    {:ok, raw_tx} = API.create_sign_off_transaction(send_height, hash, issuer)
    {:ok, signature} = Crypto.sign(raw_tx, issuer_priv)
    {:ok, _} = API.submit_transaction(raw_tx <> " " <> signature)
    
    assert %{
      "transaction" => %{
        "amount" => 5,
        "asset" => ^asset,
        "from" => ^alice,
        "nonce" => 0,
        "to" => ^bob
      },
      "type" => "finalized"
    } = TestWebsocket.recv!(websocket)
  end
  
  @tag fixtures: [:tendermint, :apis_caller]
  test "incorrect calls to websockets should return sensible response not crash", %{apis_caller: apis_caller} do
    # bad method
    {:error, %{"data" => %{"method" => "token_inf"}, "message" => "Method not found"}} = apis_caller.(:token_inf, %{token: ""})
    
    # bad params
    {:error, %{"data" => %{"msg" => "Please provide parameter `token` of type `:binary`",
                           "name" => "token",
                           "type" => "binary"
                         },
               "message" => "Invalid params"}
     } = apis_caller.(:token_info, %{toke: ""})
  end
end
