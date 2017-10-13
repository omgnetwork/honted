defmodule HonteD.JSONRPC2.Server.HandlerTest do
  @moduledoc """
  **NOTE** this test will pretend to be Tendermint core
  """
  use ExUnit.Case, async: true
  doctest HonteD

  import HonteD.JSONRPC2.Server.Handler

  defmodule TransformRequestTest do
    use ExposeSpec
    @spec basic(x :: integer, y :: integer) :: integer
    def basic(x, y) do
      x + y
    end
  end

  test "map to API, don't check the types correctness" do
    spec = TransformRequestTest._spec()
    endpoint = "basic"
    params = %{"x" => "2", "y" => "3"}
    assert {:ok, :basic, ["2", "3"]} == translate_request(endpoint, params, spec)
  end


end
