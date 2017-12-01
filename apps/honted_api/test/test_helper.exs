Code.load_file("test/testlib/api/test_helpers.ex")

ExUnitFixtures.start()
ExUnitFixtures.load_fixture_files() # need to do this in umbrella apps
ExUnit.start()

Mox.defmock(HonteD.API.TestTendermint, for: HonteD.API.TendermintBehavior)
