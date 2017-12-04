defmodule HonteD.Integration.Performance do

  alias HonteD.Integration
  
  def run(nstreams, fill_in, duration) do
    {homedir, homedir_exit_fn} = Integration.homedir()
    try do
      {:ok, _exit_fn} = Integration.honted()
      {:ok, _exit_fn} = Integration.tendermint(homedir)
      txs_source = Integration.dummy_txs_source(nstreams)

      txs_source
      |> Integration.fill_in(div(fill_in, nstreams))


      txs_source
      |> Integration.run_performance_test(duration)
      |> Enum.to_list
    after
      homedir_exit_fn.()
    end
  end
end

[:porcelain, :hackney]
|> Enum.map(&Application.ensure_all_started/1)

System.argv()
|> OptionParser.parse!(strict: [nstreams: :integer, fill_in: :integer, duration: :integer])
|> case do
  {[nstreams: nstreams, fill_in: fill_in, duration: duration], []} ->
    IO.puts(HonteD.Integration.Performance.run(nstreams, fill_in, duration))
end

