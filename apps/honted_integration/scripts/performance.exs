[:porcelain, :hackney]
|> Enum.map(&Application.ensure_all_started/1)

System.argv()
|> OptionParser.parse!(strict: [nstreams: :integer, fill_in: :integer, duration: :integer])
|> case do
  {[nstreams: nstreams, fill_in: fill_in, duration: duration], []} ->
    IO.puts(HonteD.Integration.Performance.run(nstreams, fill_in, duration))
  _ ->
    raise("Invalid commandline arguments. Look here for details on usage:")
end
