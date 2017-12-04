defmodule HonteD.Integration.Performance do
  
end

IO.puts "test"

alias HonteD.Integration

[:porcelain, :hackney]
|> Enum.map(&Application.ensure_all_started/1)

fill_in_per_stream = 200
nstreams = 10
duration = 2

{homedir, homedir_exit_fn} = Integration.homedir()
{:ok, _exit_fn} = Integration.honted()
{:ok, _exit_fn} = Integration.tendermint(homedir)
txs_source = Integration.dummy_txs_source(nstreams)

txs_source
|> Integration.fill_in(fill_in_per_stream)


txs_source
|> Integration.run_performance_test(duration)
|> Enum.to_list
|> IO.puts

