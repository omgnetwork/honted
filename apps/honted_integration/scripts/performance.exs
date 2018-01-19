[:porcelain, :hackney]
|> Enum.map(&Application.ensure_all_started/1)

System.argv()
|> OptionParser.parse!(strict: [nstreams: :integer, fill_in: :integer, duration: :integer])
|> case do
  {[nstreams: nstreams, fill_in: fill_in, duration: duration], []} ->
    IO.puts(HonteD.Integration.Performance.setup_and_run(nstreams, fill_in, duration))
  _ ->
    raise("Invalid commandline arguments. Look here for details on usage:")
end

# TODO: don't know why this is needed, should happen automatically on terminate. Does something bork at teardown?
Temp.cleanup()
