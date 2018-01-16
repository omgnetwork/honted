defmodule HonteD.EthTest do
  use ExUnit.Case
  doctest HonteD.Eth

  test "greets the world" do
    assert HonteD.Eth.hello() == :world
  end
end
