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

defmodule HonteD.CryptoTest do
  use ExUnit.Case, async: true
  @moduledoc """
  Consider removing if brittle - testing implementation details

  A sanity check of the crypto-placeholder implementation
  """

  alias HonteD.Crypto

  test "wrap unwrap sign verify" do
    {:ok, priv} = Crypto.generate_private_key
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, address} = Crypto.generate_address(pub)

    signature = Crypto.signature("message", priv)
    assert {:ok, true} == Crypto.verify("message", signature, address)
    assert {:ok, false} == Crypto.verify("message2", signature, address)
  end

end
