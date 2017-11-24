# because we want to use mix test --no-start by default
[:porcelain, :hackney]
|> Enum.map(&Application.ensure_all_started/1)

ExUnit.configure(exclude: [integration: true])
ExUnit.start()
