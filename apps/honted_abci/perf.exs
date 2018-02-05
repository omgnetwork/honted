cache = HonteD.ABCI.EthashCache.make_cache(block_number)
random_number = :rand.uniform(1000000000)
HonteD.ABCI.Ethash.calc_dataset_item(cache, random_number)
