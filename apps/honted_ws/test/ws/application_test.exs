defmodule HonteD.WS.Application.Test do
  @moduledoc """
  Test the supervision tree stuff of the app
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false

  test "HonteD Websockets should start fine" do
    assert {:ok, started} = Application.ensure_all_started(:honted_ws)
    assert :honted_ws in started
    for app <- started, do: :ok = Application.stop(app)
  end
end
