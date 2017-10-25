defmodule HonteD.WebsocketHandler do
  @behaviour :cowboy_websocket_handler

  # WS callbacks

  def init({_tcp, _http}, _req, _opts) do
    {:upgrade, :protocol, :cowboy_websocket}
  end

  def websocket_init(_transport_name, req, _opts) do
    {:ok, req, %{rqs: %{}}}
  end

  def websocket_terminate(_reason, _req, _state) do
    :ok
  end

  def websocket_handle({:text, content}, req, state) do
    try do
      resp = process_text(content)
      IO.puts("resp: #{inspect resp}")
      reply = wsrpc_response(resp)
      IO.puts("reply: #{inspect reply}")
      {:ok, encoded} = Poison.encode(reply)
      {:reply, {:text, encoded}, req, state}
    catch
      :throw, {error, data} ->
        IO.puts("error: #{inspect error}; data: #{inspect data}")
        reply = wsrpc_response({error, data});
        {:ok, encoded} = Poison.encode(reply);
        {:reply, {:text, encoded}, req, state}
    end
  end

  def websocket_handle(_data, req, state) do
    {:ok, req, state}
  end

  def websocket_info({:committed, _} = event, req, state) do
    formatted_event = wsrpc_event(event)
    {:ok, encoded} = Poison.encode(formatted_event)
    {:reply, {:text, encoded}, req, state}
  end

  def websocket_info(info, req, state) do
    IO.puts("got msg #{inspect info}")
    {:ok, req, state}
  end

  # translation and execution logic

  defp format_transaction({nonce, :send, asset, amount, src, dest, signature}) do
    tr = %{"nonce": nonce,
           "type": :send,
           "token": asset,
           "amount": amount,
           "src": src,
           "dest": dest,
           "signature": signature}
    %{"source": "filter", "type": "committed", "transaction": tr}
  end

  defp wsrpc_event({:committed, event}) do
    formatted_event = format_transaction(event)
    %{"wsrpc": "1.0", "type": "event", "data": formatted_event}
  end

  defp wsrpc_response({:ok, resp}) do
    %{"wsrpc": "1.0", "type": "rs", "result": resp}
  end
  defp wsrpc_response({:error, error}) do
    %{"wsrpc": "1.0", "type": "rs", "error": error}
  end
  defp wsrpc_response(error) when is_atom(error) do
    {code, msg} = error_code_and_message(error)
    %{"wsrpc": "1.0", "type": "rs",
      "error": %{"code": code, "message": msg}}
  end
  defp wsrpc_response({error, data}) when is_atom(error) do
    {code, msg} = error_code_and_message(error)
    %{"wsrpc": "1.0", "type": "rs",
      "error": %{"code": code, "data": data, "message": msg}}
  end

  defp error_code_and_message(:parse_error), do: {-32700, "Parse error"}
  defp error_code_and_message(:invalid_request), do: {-32600, "Invalid Request"}
  defp error_code_and_message(:method_not_found), do: {-32601, "Method not found"}
  defp error_code_and_message(:invalid_params), do: {-32602, "Invalid params"}
  defp error_code_and_message(:internal_error), do: {-32603, "Internal error"}
  defp error_code_and_message(:server_error), do: {-32000, "Server error"}

  defp zzz(a, b, c) do
    r = substitute_pid_with_self(a, b, c)
    IO.puts("a: #{inspect a}, b: #{inspect b}, c: #{inspect c} -> #{inspect r}")
    r
  end
  defp substitute_pid_with_self(_, :pid, _), do: self()
  defp substitute_pid_with_self(_, _, value), do: value

  defp process_text(content) do
    with {:ok, decoded_rq} <- decode(content),
         {:rpc, {method, params}} <- parse(decoded_rq),
         {:ok, fname, args} <- RPCTranslate.to_fa(method, params, HonteD.API.get_specs(),
                                                  &zzz/3),
      do: apply_call(HonteD.API, fname, args)
  end

  defp decode(content) do
    IO.puts("content: #{inspect content}")
    case Poison.decode(content) do
      {:ok, decoded_rq} ->
        IO.puts("decoded_rq: #{inspect decoded_rq}")
        {:ok, decoded_rq}
      {:error, _} ->
        {:error, :decode_error}
    end
  end

  def parse(request) when is_map(request) do
    version = Map.get(request, "wsrpc", :undefined)
    method = Map.get(request, "method", :undefined)
    params = Map.get(request, "params", %{})
    type = Map.get(request, "type", :undefined)
    if valid_request?(version, method, params, type) do
      IO.puts("method: #{inspect method}; params: #{inspect params}")
      {:rpc, {method, params}}
    else
      :invalid_request
    end
  end
  def parse(_) do
    :invalid_request
  end

  def valid_request?(version, method, params, type) do
    version == "1.0" and
    is_binary(method) and
    is_map(params) and
    type == "rq"
  end

  defp apply_call(module, fname, args) do
    res = :erlang.apply(module, fname, args)
    IO.puts("execution result: #{inspect res}")
    case res do
      :ok -> {:ok, :ok}
      other -> other
    end
  end

end
