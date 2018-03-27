#   Copyright 2018 OmiseGO Pte Ltd
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

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
