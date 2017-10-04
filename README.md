# HonteD

**Quick guide**:

  - `git clone ...`
  - `mix deps.get`
  - `iex -S mix`
  - elsewhere: `tendermint init`
  -
        iex(1)> HonteD.API.submit_transaction("ISSUE asset 5 bob")
        iex(2)> HonteD.API.create_send_transaction("asset", 5, "bob", "alice") |> HonteD.API.submit_transaction

Some chaotic messages will print to the REPL, among them the crude state of the application
