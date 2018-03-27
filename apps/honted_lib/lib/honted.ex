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

defmodule HonteD do
  @moduledoc """
  All stateless and generic functionality, shared application logic
  """
  @type address :: String.t
  @type token :: String.t
  @type signature :: String.t
  @type nonce :: non_neg_integer
  @type block_hash :: String.t # NOTE: this is a hash external to our APP i.e. consensus engine based, e.g. TM block has
  @type block_height :: pos_integer
  @type epoch_number :: pos_integer
  @type privilege :: String.t
  @type filter_id :: reference
end
