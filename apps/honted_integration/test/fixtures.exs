defmodule HonteD.Integration.Fixtures do
  use ExUnitFixtures.FixtureModule

  alias HonteD.Integration

  deffixture homedir() do
    Integration.homedir()
  end

  deffixture tendermint(homedir, honted) do
    IO.puts("deffixture.tendermint")
    {:ok, exit_fn} = Integration.tendermint(homedir)
    on_exit exit_fn
    :ok
  end

  deffixture honted() do
    IO.puts("deffixture.honted")
    {:ok, geth_exit} = Integration.geth()
    {:ok, honted_exit} = Integration.honted()
    exit_fn = fn() ->
      IO.puts("deffixture.honted combined on_exit")
      honted_exit.()
      geth_exit.()
    end
    on_exit exit_fn
    :ok
  end

end
