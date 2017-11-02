defmodule HonteD.API.RPCTranslateTest do
  @moduledoc """
  """
  use ExUnit.Case, async: true

  defmodule TransformRequestTest do
    use HonteD.API.ExposeSpec
    @spec basic(x :: integer, y :: integer) :: integer
    def basic(x, y) do
      x + y
    end
  end

  test "map to API, don't check the types correctness" do
    spec = TransformRequestTest.get_specs()
    method = "basic"
    params = %{"x" => "2", "y" => "3"}
    assert {:ok, :basic, ["2", "3"]} == HonteD.API.RPCTranslate.to_fa(method, params, spec)
  end


end
