defmodule HonteD.ABCI.Application.Test do
  @moduledoc """
  Test the supervision tree stuff of the app
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false

  test "ABCI should start fine" do
    assert {:ok, started} = Application.ensure_all_started(:honted_abci)
    assert :honted_abci in started
    for app <- started, do: :ok = Application.stop(app)
  end
end
