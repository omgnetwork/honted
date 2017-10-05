# HonteD

**Quick guide**:

  - `git clone ...`
  - `mix deps.get`
  - `iex -S mix`
  - elsewhere:
    - `tendermint init` (once)
    - `tendermint --log_level "*:info" node` (everytime to start Tendermint)
  - then in the `iex` REPL
        iex(1)> HonteD.API.submit_transaction("ISSUE asset 5 bob")
        iex(2)> HonteD.API.create_send_transaction("asset", 5, "bob", "alice") |> HonteD.API.submit_transaction
        iex(3)> HonteD.API.query_balance("asset", "alice")


Do `tendermint unsafe_reset_all` everytime you want to clean the databases and start from scratch.

Some chaotic messages will print to the REPL, among them the crude state of the application
