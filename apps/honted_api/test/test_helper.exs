Code.load_file("test/testlib/api/test_helpers.ex")
ExUnit.start()
Mox.defmock(HonteD.API.TestTendermint, for: HonteD.API.TendermintBehavior)
