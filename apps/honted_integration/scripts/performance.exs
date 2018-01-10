System.argv()
|> OptionParser.parse!(strict: [nstreams: :integer, fill_in: :integer, duration: :integer])
|> case do
  {[nstreams: nstreams, fill_in: fill_in, duration: duration], []} ->
    IO.puts(HonteD.Integration.Performance.setup_and_run(nstreams, fill_in, duration))
  _ ->
    raise("Invalid commandline arguments. Look here for details on usage:")
end
