defmodule HonteD.TransactionTest do
  @moduledoc """
  This test could test the stateless features of the HonteD lib, like the transaction validation etc.
  For now this functionality _is tested_ but via its application in honted (abci_test).
  This is the mission critical application of the transaction validation functionality, and seems natural there.
  
  This is the reason for `skip_files` in `coveralls.json`

  Since, from the point of view of Lib's and API's API, it is only a convenience functionality, let's postpone handling
  this testing independently from ABCI.
  
  Possible way of testing ABCI vs Lib:
   - test details of behavior of transactions/ encodings etc. in Lib tests
   - test this functionality being called in ABCI in ABCI tests
  """
  # NOTE: implement these tests (:troll:)
end
